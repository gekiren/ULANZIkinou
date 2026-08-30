param (
    [string]$Action,
    [string]$DeviceName,
    [double]$Value
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$csharpCode = @"
using System;
using System.Runtime.InteropServices;
using System.Text;

[StructLayout(LayoutKind.Sequential)]
public struct PropertyKey {
    public Guid fmtid;
    public int pid;
}

[StructLayout(LayoutKind.Explicit)]
public struct PropVariant {
    [FieldOffset(0)] public short vt;
    [FieldOffset(8)] public IntPtr ptr;
    
    public string GetString() {
        if (vt == 31 && ptr != IntPtr.Zero) {
            return Marshal.PtrToStringUni(ptr);
        }
        return null;
    }
}

[Guid("886d8eeb-8cf2-4446-8d02-cdba1dbdcf99"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPropertyStore {
    int GetCount(out int cProps);
    int GetAt(int iProp, out PropertyKey key);
    int GetValue(ref PropertyKey key, out PropVariant pv);
    int SetValue(ref PropertyKey key, ref PropVariant pv);
    int Commit();
}

[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
    int f(); int g(); int h(); int i();
    int SetMasterVolumeLevelScalar(float fLevel, Guid pguidEventContext);
    int j();
    int GetMasterVolumeLevelScalar(out float pfLevel);
    int k(); int l(); int m(); int n();
    int SetMute([MarshalAs(UnmanagedType.Bool)] bool bMute, Guid pguidEventContext);
    int GetMute([MarshalAs(UnmanagedType.Bool)] out bool pbMute);
}

[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
    int Activate(ref Guid id, int clsCtx, int activationParams, out IAudioEndpointVolume aev);
    int OpenPropertyStore(int stgmAccess, out IPropertyStore properties);
    int GetId(out string ppstrId);
    int GetState(out int pdwState);
}

[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection {
    int GetCount(out int pcDevices);
    int Item(int nDevice, out IMMDevice device);
}

[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
    int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices);
    int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice endpoint);
    int GetDevice(string pwstrId, out IMMDevice endpoint);
}

[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject { }

public class AudioControl {
    private static Guid IID_IAudioEndpointVolume = typeof(IAudioEndpointVolume).GUID;
    private static PropertyKey PKEY_Device_FriendlyName = new PropertyKey {
        fmtid = new Guid("a45c254e-df1c-4efd-8020-67d146a850e0"),
        pid = 14
    };

    private static IMMDevice FindDevice(string searchName) {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDeviceCollection collection = null;
        if (enumerator.EnumAudioEndpoints(1, 1, out collection) != 0) return null;
        
        int count = 0;
        if (collection.GetCount(out count) != 0) return null;

        for (int i = 0; i < count; i++) {
            IMMDevice device = null;
            if (collection.Item(i, out device) != 0) continue;

            IPropertyStore store = null;
            if (device.OpenPropertyStore(0, out store) == 0) {
                PropVariant pv;
                if (store.GetValue(ref PKEY_Device_FriendlyName, out pv) == 0) {
                    string name = pv.GetString();
                    if (name != null && name.IndexOf(searchName, StringComparison.OrdinalIgnoreCase) >= 0) {
                        return device;
                    }
                }
            }
        }
        return null;
    }

    private static IAudioEndpointVolume GetVolumeControl(string deviceName) {
        IMMDevice device = null;
        if (string.IsNullOrEmpty(deviceName) || deviceName.Equals("default", StringComparison.OrdinalIgnoreCase)) {
            var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
            if (enumerator.GetDefaultAudioEndpoint(1, 1, out device) != 0) return null;
        } else {
            device = FindDevice(deviceName);
        }
        if (device == null) return null;

        IAudioEndpointVolume volume = null;
        if (device.Activate(ref IID_IAudioEndpointVolume, 23, 0, out volume) == 0) {
            return volume;
        }
        return null;
    }

    public static float GetVolume(string deviceName) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return -1f;
        float level = 0f;
        vol.GetMasterVolumeLevelScalar(out level);
        return level;
    }

    public static bool SetVolume(string deviceName, float level) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return false;
        return vol.SetMasterVolumeLevelScalar(level, Guid.Empty) == 0;
    }

    public static int GetMute(string deviceName) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return -1;
        bool mute = false;
        vol.GetMute(out mute);
        return mute ? 1 : 0;
    }

    public static bool SetMute(string deviceName, bool mute) {
        var vol = GetVolumeControl(deviceName);
        if (vol == null) return false;
        return vol.SetMute(mute, Guid.Empty) == 0;
    }

    public static string GetDevices() {
        var enumerator = new MMDeviceEnumeratorComObject() as IMMDeviceEnumerator;
        IMMDeviceCollection collection = null;
        if (enumerator.EnumAudioEndpoints(1, 1, out collection) != 0) return "";
        int count = 0;
        if (collection.GetCount(out count) != 0) return "";
        
        var sb = new StringBuilder();
        for (int i = 0; i < count; i++) {
            IMMDevice device = null;
            if (collection.Item(i, out device) != 0) continue;
            IPropertyStore store = null;
            if (device.OpenPropertyStore(0, out store) == 0) {
                PropVariant pv;
                if (store.GetValue(ref PKEY_Device_FriendlyName, out pv) == 0) {
                    string name = pv.GetString();
                    if (name != null) {
                        sb.AppendLine(name);
                    }
                }
            }
        }
        return sb.ToString();
    }
}
"@

Add-Type -TypeDefinition $csharpCode -ErrorAction SilentlyContinue

switch ($Action) {
    "GetDevices" {
        [AudioControl]::GetDevices()
    }
    "GetVolume" {
        [AudioControl]::GetVolume($DeviceName)
    }
    "SetVolume" {
        [AudioControl]::SetVolume($DeviceName, $Value)
    }
    "GetMute" {
        [AudioControl]::GetMute($DeviceName)
    }
    "SetMute" {
        [AudioControl]::SetMute($DeviceName, ($Value -eq 1))
    }
    default {
        Write-Error "Unknown action: $Action"
    }
}
