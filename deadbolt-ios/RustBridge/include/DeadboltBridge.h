#ifndef DEADBOLT_BRIDGE_H
#define DEADBOLT_BRIDGE_H
char *deadbolt_request(const char *request);
void deadbolt_cancel(const char *data_dir);
void deadbolt_free(char *response);
#endif
