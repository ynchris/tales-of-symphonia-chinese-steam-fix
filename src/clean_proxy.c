#define WIN32_LEAN_AND_MEAN
#include <windows.h>

static FARPROC pSteamApps;
static FARPROC pSteamAPI_Init;
static FARPROC pSteamAPI_UnregisterCallback;
static FARPROC pSteamAPI_RegisterCallback;
static FARPROC pSteamUser;
static FARPROC pSteamUserStats;
static FARPROC pSteamUtils;
static FARPROC pSteamAPI_RunCallbacks;
static FARPROC pSteamRemoteStorage;

typedef void *(__cdecl *interface_getter)(void);
typedef int (__cdecl *steam_init)(void);
typedef void (__cdecl *callback_unregister)(void *callback);
typedef void (__cdecl *callback_register)(void *callback, int callback_id);
typedef void (__cdecl *run_callbacks)(void);

__declspec(dllexport) void *SteamApps(void) { return ((interface_getter)pSteamApps)(); }
__declspec(dllexport) int SteamAPI_Init(void) { return ((steam_init)pSteamAPI_Init)(); }
__declspec(dllexport) void SteamAPI_UnregisterCallback(void *p) { ((callback_unregister)pSteamAPI_UnregisterCallback)(p); }
__declspec(dllexport) void SteamAPI_RegisterCallback(void *p, int id) { ((callback_register)pSteamAPI_RegisterCallback)(p, id); }
__declspec(dllexport) void *SteamUser(void) { return ((interface_getter)pSteamUser)(); }
__declspec(dllexport) void *SteamUserStats(void) { return ((interface_getter)pSteamUserStats)(); }
__declspec(dllexport) void *SteamUtils(void) { return ((interface_getter)pSteamUtils)(); }
__declspec(dllexport) void SteamAPI_RunCallbacks(void) { ((run_callbacks)pSteamAPI_RunCallbacks)(); }
__declspec(dllexport) void *SteamRemoteStorage(void) { return ((interface_getter)pSteamRemoteStorage)(); }

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID reserved)
{
    HMODULE steam;

    (void)reserved;
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(instance);
        steam = LoadLibraryW(L"steam_api.dll");
        if (!steam)
            return FALSE;
        pSteamApps = GetProcAddress(steam, "SteamApps");
        pSteamAPI_Init = GetProcAddress(steam, "SteamAPI_Init");
        pSteamAPI_UnregisterCallback = GetProcAddress(steam, "SteamAPI_UnregisterCallback");
        pSteamAPI_RegisterCallback = GetProcAddress(steam, "SteamAPI_RegisterCallback");
        pSteamUser = GetProcAddress(steam, "SteamUser");
        pSteamUserStats = GetProcAddress(steam, "SteamUserStats");
        pSteamUtils = GetProcAddress(steam, "SteamUtils");
        pSteamAPI_RunCallbacks = GetProcAddress(steam, "SteamAPI_RunCallbacks");
        pSteamRemoteStorage = GetProcAddress(steam, "SteamRemoteStorage");
        if (!pSteamApps || !pSteamAPI_Init || !pSteamAPI_UnregisterCallback ||
            !pSteamAPI_RegisterCallback || !pSteamUser || !pSteamUserStats ||
            !pSteamUtils || !pSteamAPI_RunCallbacks || !pSteamRemoteStorage)
            return FALSE;
#ifndef NO_TRANSLATION
        if (!LoadLibraryW(L"3dm32.dll"))
            return FALSE;
#endif
    }
    return TRUE;
}
