use super::DefaultRouteDetails;
pub(super) use super::netdev_impl::{get_state, home_router};
pub(super) async fn default_route() -> Option<DefaultRouteDetails> {
    netdev::get_default_interface().ok().map(|i|DefaultRouteDetails{interface_name:i.name})
}
