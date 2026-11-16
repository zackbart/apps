mod exchange;
mod network;
mod state;
mod transport;
use anyhow::{Context, Result, bail};
use data_encoding::{BASE64, HEXLOWER};
use deadbolt_core::{Change, DataOp, DeviceId, Field, FieldType, Item, ItemId, Vault, VaultId};
use deadbolt_net::{PairingCode, PairingOptions};
use network::{Handler, Shared};
use serde_json::{Value, json};
use state::Session;
use std::{
    collections::BTreeMap,
    ffi::{CStr, CString, c_char},
    path::Path,
    sync::{Arc, Mutex, OnceLock},
    time::{Duration, SystemTime, UNIX_EPOCH},
};
fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}
fn unhex<const N: usize>(s: &str) -> Result<[u8; N]> {
    HEXLOWER
        .decode(s.as_bytes())?
        .try_into()
        .map_err(|_| anyhow::anyhow!("Invalid identifier"))
}
fn text<'a>(v: &'a Value, k: &str) -> Result<&'a str> {
    v[k].as_str().with_context(|| format!("Missing {k}"))
}
struct Engine {
    session: Shared,
    transport: transport::Transport,
    sync: Arc<Mutex<Value>>,
    sync_task: Option<tokio::task::JoinHandle<()>>,
    pair: Arc<Mutex<Value>>,
    pair_task: Option<tokio::task::JoinHandle<()>>,
}
impl Engine {
    fn new() -> Self {
        Self {
            session: Arc::new(Mutex::new(None)),
            transport: transport::Transport::default(),
            sync: Arc::new(Mutex::new(json!({"state":"idle"}))),
            sync_task: None,
            pair: Arc::new(Mutex::new(json!({"state":"idle"}))),
            pair_task: None,
        }
    }
    fn with<T>(&self, f: impl FnOnce(&mut Session) -> Result<T>) -> Result<T> {
        let mut g = self
            .session
            .lock()
            .map_err(|_| anyhow::anyhow!("State unavailable"))?;
        let s = g.as_mut().context("Vault is locked")?;
        anyhow::ensure!(!s.poisoned, "Unlock again to authenticate the store");
        f(s)
    }
    async fn start(&mut self, s: Session) -> Result<()> {
        *self
            .session
            .lock()
            .map_err(|_| anyhow::anyhow!("State unavailable"))? = Some(s);
        Ok(())
    }
    async fn ensure_network(&mut self) -> Result<()> {
        self.transport.ensure(self.session.clone()).await?;
        Ok(())
    }
    async fn close(&mut self) {
        if let Some(task) = self.sync_task.take() {
            task.abort();
            let _ = task.await;
        }
        if let Some(task) = self.pair_task.take() {
            task.abort();
            let _ = task.await;
        }
        if let Ok(mut guard) = self.session.lock() {
            *guard = None;
        }
        self.transport.close().await;
        if let Ok(mut status) = self.pair.lock() {
            *status = json!({"state":"idle"});
        }
        if let Ok(mut status) = self.sync.lock() {
            *status = json!({"state":"idle"});
        }
    }
    fn status(&self, dir: &Path) -> Value {
        let pairing = self.pair.lock().map(|v| v.clone()).unwrap_or(Value::Null);
        self.with(|s|Ok(json!({"initialized":true,"locked":false,"device_id":s.secret.device_id().to_string(),"device_name":s.name,"vaults":s.vaults.values().map(|v|json!({"id":v.id().to_string(),"name":v.name()})).collect::<Vec<_>>(),"pairing":pairing}))).unwrap_or_else(|_|json!({"initialized":deadbolt_store::is_initialized(dir),"locked":true,"vaults":[],"pairing":pairing}))
    }
    fn vault(&self, v: &Value) -> Result<VaultId> {
        self.with(|s| {
            let id = if let Some(id) = v["vault_id"].as_str() {
                VaultId::from_bytes(unhex(id)?)
            } else {
                anyhow::ensure!(s.vaults.len() == 1, "Choose a vault explicitly");
                *s.vaults.keys().next().context("No vault available")?
            };
            let vault = s.vaults.get(&id).context("Vault not held")?;
            anyhow::ensure!(
                vault.is_member(&s.secret.device_id()),
                "This device is not a member of the vault"
            );
            Ok(id)
        })
    }
    async fn request(&mut self, v: Value) -> Result<Value> {
        let dir = Path::new(text(&v, "data_dir")?);
        match text(&v,"op")? {
            "status"=>Ok(self.status(dir)),
            "lock"=>{self.close().await;Ok(self.status(dir))},
            "create"=>{let name=v["vault_name"].as_str().unwrap_or("personal");anyhow::ensure!(name.is_empty()||deadbolt_core::valid_name(name),"Invalid vault name");self.close().await;let mut s=Session::create(dir,text(&v,"passphrase")?,v["device_name"].as_str().unwrap_or("iPhone"))?;if !name.is_empty(){let (vault,_)=Vault::create(&s.secret,name)?;s.add_vault(vault)?;}self.start(s).await?;Ok(self.status(dir))},
            "create_vault"=>{let name=text(&v,"name")?;anyhow::ensure!(deadbolt_core::valid_name(name),"Invalid vault name");self.with(|s|{let (vault,_)=Vault::create(&s.secret,name)?;let result=json!({"id":vault.id().to_string(),"name":vault.name()});s.add_vault(vault)?;Ok(result)})},
            "unlock"|"unlock_key"=>{self.close().await;let store=if v["op"]=="unlock"{deadbolt_store::unlock(dir,text(&v,"passphrase")?.as_bytes())?}else{deadbolt_store::unlock_biometric(dir,&unhex(text(&v,"key")?)?)?};self.start(Session::open(store)?).await?;Ok(self.status(dir))},
            "biometric_enable"=>self.with(|s|{let key=deadbolt_store::generate_biometric_key()?;s.store.set_biometric(&key,b"ios-keychain-v1")?;Ok(json!({"key":HEXLOWER.encode(key.as_ref())}))}),
            "biometric_disable"=>self.with(|s|{s.store.clear_biometric()?;Ok(json!({}))}),
            "list"|"export"=>self.with(|s|Ok(json!(s.vaults.values().flat_map(|vault|vault.items().into_iter().filter(|i|!i.deleted).map(move|i|item_json(vault.id(),i))).collect::<Vec<_>>()))),
            "credential_exchange_import"=>{
                let vault=self.vault(&v)?;
                let items=v["items"].as_array().context("Missing credentials")?;
                self.with(|s|exchange::import(s,vault,items))
            },
            "import"=>{
                let vault=self.vault(&v)?;
                let items=v["items"].as_array().context("Missing items")?;
                let ops=items.iter().map(|item|{let kind=item["type"].as_str().unwrap_or("login");anyhow::ensure!(kind!="passkey","Passkeys must be paired through the signed vault");Ok(DataOp::create(kind,item["name"].as_str().map(String::from),parse_fields(&item["fields"])?))}).collect::<Result<Vec<_>>>()?;
                self.with(|s|{
                    let mut planned=Vec::new();let mut skipped=0;
                    let mut existing=s.vaults[&vault].iter_items().map(|item|import_identity(&item.kind,&item.name,&item.fields)).collect::<Result<std::collections::BTreeSet<_>>>()?;
                    for op in ops {
                        if v["deduplicate"]==true {
                            if let DataOp::Create{kind,name,fields,..}=&op {
                                let identity=import_identity(kind,name,fields)?;
                                if !existing.insert(identity){skipped+=1;continue;}
                            }
                        }
                        planned.push(op);
                    }
                    s.mutate(vault,|w,key|{let (ids,_)=w.create_items(key,planned)?;Ok(json!({"ids":ids.iter().map(ToString::to_string).collect::<Vec<_>>(),"imported":ids.len(),"skipped":skipped}))})
                })
            },
            "get"=>{let vault=self.vault(&v)?;let id=ItemId::from_bytes(unhex(text(&v,"id")?)?);self.with(|s|Ok(item_json(vault,s.vaults.get(&vault).and_then(|v|v.item(&id)).context("Item not found")?)))},
            "save"=>{let vault=self.vault(&v)?;let fields=parse_fields(&v["fields"])?;let name=v["name"].as_str().map(String::from);let id=if let Some(id)=v["id"].as_str(){let id=ItemId::from_bytes(unhex(id)?);self.with(|s|s.mutate(vault,|w,key|{let old=w.item(&id).context("Item not found")?;anyhow::ensure!(!old.deleted,"Item was deleted; reload before editing");if let Some(expected)=v.get("expected"){let expected_name=text(expected,"name")?;let expected_fields=parse_fields(&expected["fields"])?;anyhow::ensure!(old.name.as_deref().unwrap_or_default()==expected_name&&old.fields==expected_fields,"Item changed on another device; reload before editing");}anyhow::ensure!(old.kind!="passkey","Passkeys cannot be edited as passwords");let mut ops=vec![DataOp::Edit{item:id,change:Change::Name(name)}];if let Some(removals)=v["remove_fields"].as_array(){let schema=deadbolt_core::schema(&old.kind).context("Unknown item type")?;for removal in removals{let field=removal.as_str().context("Invalid field removal")?;anyhow::ensure!(schema.field(field).is_some_and(|f|!f.required),"Only optional schema fields can be removed");if old.fields.contains_key(field){ops.push(DataOp::Edit{item:id,change:Change::Remove{field:field.into()}});}}}for (k,value) in fields{ops.push(DataOp::Edit{item:id,change:Change::Set{field:k,value}});}if let Some(favorite)=v["favorite"].as_bool(){ops.push(DataOp::Edit{item:id,change:Change::Favorite(favorite)});}w.write(key,ops)?;Ok(id)}))?}else{self.with(|s|s.mutate(vault,|w,key|Ok(w.create_item(key,v["type"].as_str().unwrap_or("login"),name,fields)?.0)))?};self.with(|s|Ok(item_json(vault,s.vaults[&vault].item(&id).context("Item not found")?)))},
            "delete"=>{let vault=self.vault(&v)?;let id=ItemId::from_bytes(unhex(text(&v,"id")?)?);self.with(|s|s.mutate(vault,|w,key|{w.write(key,vec![DataOp::Edit{item:id,change:Change::Delete{at:Some(now())}}])?;Ok(json!({}))}))},
            "passkey_list"=>self.with(|s|Ok(json!(s.vaults.values().flat_map(|vault|vault.items().into_iter().filter(|i|!i.deleted&&i.kind=="passkey").map(move|i|passkey_metadata(vault.id(),&i))).collect::<Result<Vec<_>>>()?))),
            "passkey_register"=>{
                anyhow::ensure!(v["verified"]==true,"User verification is required");
                if let Some(algorithms)=v["algorithms"].as_array(){anyhow::ensure!(algorithms.iter().any(|a|a.as_i64()==Some(-7)),"Only ES256 passkeys are supported");}
                let vault=self.vault(&v)?;
                let hash=to_url(text(&v,"client_data_hash")?)?;
                let handle=to_url(text(&v,"user_handle")?)?;
                let exclude=v["exclude"].as_array().map(|a|a.iter().map(|v|to_url(v.as_str().context("Invalid excluded credential")?)).collect::<Result<Vec<_>>>()).transpose()?.unwrap_or_default();
                let new=deadbolt_core::passkeys::check_create_hash(text(&v,"rp_id")?,&hash,&handle,text(&v,"username")?,&exclude)?;
                self.with(|s|{
                    let items=s.vaults.values().flat_map(|v|v.items()).collect::<Vec<_>>();
                    deadbolt_core::passkeys::check_excluded(items.iter(),&new.rp_id,&exclude)?;
                    let date=time::OffsetDateTime::now_utc().date().to_string();
                    let made=deadbolt_core::passkeys::register_hash(&new,true,&date)?;
                    let id=s.mutate(vault,|w,key|{let entry=w.write(key,vec![made.create])?;Ok(ItemId::of_create(&entry.hash(),0))})?;
                    Ok(json!({"id":id.to_string(),"vault_id":vault.to_string(),"credential_id":to_base64(&made.credential_id)?,"attestation_object":to_base64(&made.attestation_object)?,"authenticator_data":to_base64(&made.authenticator_data)?,"public_key":to_base64(&made.public_key)?}))
                })
            },
            "passkey_assert"=>{
                anyhow::ensure!(v["verified"]==true,"User verification is required");
                let rp=text(&v,"rp_id")?;
                let hash=to_url(text(&v,"client_data_hash")?)?;
                let credential=v["credential_id"].as_str().map(to_url).transpose()?;
                self.with(|s|{
                    let items=s.vaults.values().flat_map(|v|v.items()).filter(|item|deadbolt_core::passkeys::matches(item,rp)&&credential.as_ref().is_none_or(|c|item.fields.get("credential-id").is_some_and(|f|&f.value==c))).collect::<Vec<_>>();
                    anyhow::ensure!(items.len()==1,"Choose one matching passkey");
                    let signed=deadbolt_core::passkeys::sign_hash(&items[0],rp,&hash,true)?;
                    Ok(json!({"credential_id":to_base64(&signed.credential_id)?,"user_handle":to_base64(&signed.user_handle)?,"authenticator_data":to_base64(&signed.authenticator_data)?,"signature":to_base64(&signed.signature)?}))
                })
            },
            "devices"=>self.with(|s|{let me=s.secret.device_id();let mut ids=std::collections::BTreeSet::new();for vault in s.vaults.values(){ids.extend(vault.members());}Ok(json!(ids.into_iter().map(|id|json!({"id":id.to_string(),"name":if id==me {Some(s.name.clone())}else{s.peers.get(&id.to_string()).and_then(|p|p.name.clone())},"this":id==me,"connected":self.transport.current().as_ref().is_some_and(|n|n.connected_peers().contains(id.as_bytes()))})).collect::<Vec<_>>()))}),
            "remove_device"=>{
                let id=DeviceId::from_bytes(unhex(text(&v,"id")?)?);
                let targets=self.with(|s|{
                    anyhow::ensure!(id!=s.secret.device_id(),"This device cannot remove itself");
                    if let Some(vault)=v["vault_id"].as_str(){Ok(vec![VaultId::from_bytes(unhex(vault)?)])}else{Ok(s.vaults.values().filter(|vault|vault.is_member(&id)).map(Vault::id).collect::<Vec<_>>())}
                })?;
                anyhow::ensure!(!targets.is_empty(),"Device is not a member of any held vault");
                let mut removed=Vec::new();
                for vault in targets {
                    let result=self.with(|s|s.mutate(vault,|w,key|{w.remove(key,id)?;Ok(())}));
                    if let Some(node)=self.transport.current(){node.enforce_membership();}
                    result.with_context(||format!("Removed from {} vaults; failed to revoke remaining vault {}",removed.len(),vault))?;
                    removed.push(vault.to_string());
                }
                Ok(json!({"vault_ids":removed}))
            },
            "join_start"=>{self.ensure_network().await?;if let Some(t)=self.pair_task.take(){t.abort();let _=t.await;}let node=self.transport.current().context("Unlock first")?;let code=PairingCode::generate()?;let listener=node.start_pairing(&code,PairingOptions::default()).await?;let status=json!({"state":"waiting","code":code.text().as_str()});*self.pair.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?=status.clone();let pair=self.pair.clone();let handler=Handler(self.session.clone());self.pair_task=Some(tokio::spawn(async move{let joiner=network::NewDevice{handler,offer:Mutex::new(None)};let result=listener.complete(&joiner).await;let value=match result{Ok(out)=>json!({"state":"complete","peer":HEXLOWER.encode(&out.peer)}),Err(e)=>json!({"state":"failed","error":e.to_string()})};if let Ok(mut p)=pair.lock(){*p=value;}}));Ok(status)},
            "pair_cancel"=>{if let Some(task)=self.pair_task.take(){task.abort();let _=task.await;}let idle=json!({"state":"idle"});*self.pair.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?=idle.clone();Ok(idle)},
            "pairing_status"=>Ok(self.pair.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?.clone()),
            "approve"=>{self.ensure_network().await?;let vault=self.vault(&v)?;let code:PairingCode=text(&v,"code")?.parse()?;let handler=network::ExistingDevice{handler:Handler(self.session.clone()),vault};let outcome=self.transport.current().context("Unlock first")?.pair(&code,PairingOptions::default(),&handler).await?;Ok(json!({"peer":HEXLOWER.encode(&outcome.peer)}))},
            "sync"=>{
                self.with(|_|Ok(()))?;if transport::targets(&self.session)?.is_empty(){if let Some(task)=self.sync_task.take(){task.abort();let _=task.await;}let value=json!({"state":"complete","results":[]});*self.sync.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?=value.clone();return Ok(value);}
                if self.sync_task.as_ref().is_some_and(|task|!task.is_finished()){return Ok(self.sync.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?.clone());}
                *self.sync.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?=json!({"state":"running"});
                let shared=self.session.clone();let transport=self.transport.clone();let status=self.sync.clone();
                self.sync_task=Some(tokio::spawn(async move {
                    let work=async{let node=transport.ensure(shared.clone()).await?;let (results,_,_)=transport::round(&node,transport::targets(&shared)?,Duration::from_secs(8),Duration::from_secs(20)).await;Ok::<_,anyhow::Error>(json!({"state":"complete","results":results}))};
                    let result=match tokio::time::timeout(Duration::from_secs(45),work).await{Ok(Ok(value))=>value,Ok(Err(error))=>json!({"state":"failed","error":error.to_string()}),Err(_)=>json!({"state":"failed","error":"Sync job timed out"})};
                    if let Ok(mut guard)=status.lock(){*guard=result;}
                }));
                Ok(json!({"state":"running"}))
            },
            "sync_status"=>Ok(self.sync.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?.clone()),
            "sync_cancel"=>{if let Some(task)=self.sync_task.take(){task.abort();let _=task.await;}let value=json!({"state":"idle"});*self.sync.lock().map_err(|_|anyhow::anyhow!("State unavailable"))?=value.clone();Ok(value)},
            _=>bail!("Unknown operation")
        }
    }
}
fn item_json(vault: VaultId, item: Item) -> Value {
    let passkey = item.kind == "passkey";
    json!({"id":item.id.to_string(),"vault_id":vault.to_string(),"type":item.kind,"name":item.name.unwrap_or_default(),"fields":item.fields.into_iter().filter(|(k,_)|!passkey||k!="private-key").map(|(k,f)|(k,json!({"type":f.kind.as_str(),"value":f.value}))).collect::<BTreeMap<_,_>>(),"favorite":item.favorite,"tags":item.tags})
}
fn to_url(value: &str) -> Result<String> {
    Ok(deadbolt_core::webauthn::b64(
        &BASE64.decode(value.as_bytes())?,
    ))
}
fn to_base64(value: &str) -> Result<String> {
    Ok(BASE64.encode(&deadbolt_core::webauthn::unb64(value)?))
}
fn passkey_metadata(vault: VaultId, item: &Item) -> Result<Value> {
    let field = |name: &str| {
        item.fields
            .get(name)
            .map(|f| f.value.as_str())
            .context("Incomplete passkey")
    };
    Ok(
        json!({"id":item.id.to_string(),"vault_id":vault.to_string(),"rp_id":field("rp-id")?,"username":item.fields.get("username").map(|f|f.value.as_str()).unwrap_or_default(),"credential_id":to_base64(field("credential-id")?)?,"user_handle":to_base64(field("user-handle")?)?}),
    )
}
fn import_identity(
    kind: &str,
    name: &Option<String>,
    fields: &BTreeMap<String, Field>,
) -> Result<String> {
    let fields = fields
        .iter()
        .map(|(name, field)| (name, (field.kind.as_str(), &field.value)))
        .collect::<BTreeMap<_, _>>();
    Ok(serde_json::to_string(&(kind, name, fields))?)
}
fn parse_fields(v: &Value) -> Result<BTreeMap<String, Field>> {
    v.as_object()
        .context("Missing fields")?
        .iter()
        .map(|(k, f)| {
            Ok((
                k.clone(),
                Field {
                    kind: FieldType::parse(text(f, "type")?),
                    value: text(f, "value")?.into(),
                },
            ))
        })
        .collect()
}
static RUNTIME: OnceLock<tokio::runtime::Runtime> = OnceLock::new();
type EngineHandle = Arc<Mutex<Engine>>;
static ENGINES: OnceLock<Mutex<BTreeMap<String, EngineHandle>>> = OnceLock::new();
static CANCELS: OnceLock<Mutex<BTreeMap<String, Arc<tokio::sync::Notify>>>> = OnceLock::new();
pub fn request_json(input: &str) -> String {
    let result = std::panic::catch_unwind(|| -> Result<Value> {
        let request: Value = serde_json::from_str(input)?;
        let dir = text(&request, "data_dir")?.to_string();
        let closing = request["op"] == "lock";
        let cancel = {
            let mut cancels = CANCELS
                .get_or_init(|| Mutex::new(BTreeMap::new()))
                .lock()
                .map_err(|_| anyhow::anyhow!("Engine unavailable"))?;
            cancels
                .entry(dir.clone())
                .or_insert_with(|| Arc::new(tokio::sync::Notify::new()))
                .clone()
        };
        if closing {
            cancel.notify_one();
        }
        let handle = {
            let mut engines = ENGINES
                .get_or_init(|| Mutex::new(BTreeMap::new()))
                .lock()
                .map_err(|_| anyhow::anyhow!("Engine unavailable"))?;
            engines
                .entry(dir)
                .or_insert_with(|| Arc::new(Mutex::new(Engine::new())))
                .clone()
        };
        let mut engine = handle
            .lock()
            .map_err(|_| anyhow::anyhow!("Engine unavailable"))?;
        RUNTIME
            .get_or_init(|| {
                tokio::runtime::Builder::new_multi_thread()
                    .enable_all()
                    .build()
                    .expect("Tokio runtime")
            })
            .block_on(async {
                if closing {
                    let _ = tokio::time::timeout(Duration::ZERO, cancel.notified()).await;
                    engine.close().await;
                    return Ok(engine.status(Path::new(text(&request, "data_dir")?)));
                }
                let result = tokio::select! {
                    result=engine.request(request)=>Some(result),
                    _=cancel.notified()=>None,
                };
                match result {
                    Some(r) => r,
                    None => {
                        engine.close().await;
                        bail!("Operation cancelled because vault was locked")
                    }
                }
            })
    });
    match result {
        Ok(Ok(result)) => json!({"ok":true,"result":result}).to_string(),
        Ok(Err(e)) => json!({"ok":false,"error":format!("{e:#}")}).to_string(),
        Err(_) => json!({"ok":false,"error":"Engine operation failed"}).to_string(),
    }
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn deadbolt_request(input: *const c_char) -> *mut c_char {
    let result = if input.is_null() {
        json!({"ok":false,"error":"Missing request"}).to_string()
    } else {
        match unsafe { CStr::from_ptr(input) }.to_str() {
            Ok(s) => request_json(s),
            Err(_) => json!({"ok":false,"error":"Invalid UTF-8"}).to_string(),
        }
    };
    CString::new(result)
        .map(CString::into_raw)
        .unwrap_or(std::ptr::null_mut())
}
#[unsafe(no_mangle)]
pub unsafe extern "C" fn deadbolt_free(response: *mut c_char) {
    if !response.is_null() {
        let mut bytes = unsafe { CString::from_raw(response) }.into_bytes_with_nul();
        zeroize::Zeroize::zeroize(&mut bytes);
    }
}
#[cfg(test)]
mod tests;

#[unsafe(no_mangle)]
pub unsafe extern "C" fn deadbolt_cancel(data_dir: *const c_char) {
    if data_dir.is_null() {
        return;
    }
    let Ok(dir) = unsafe { CStr::from_ptr(data_dir) }.to_str() else {
        return;
    };
    if let Some(registry) = CANCELS.get() {
        if let Ok(cancels) = registry.lock() {
            if let Some(cancel) = cancels.get(dir) {
                cancel.notify_one();
            }
        }
    }
}
