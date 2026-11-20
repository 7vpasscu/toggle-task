using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text.Json;
using Microsoft.Win32;
namespace ToggleTask;
public sealed class AppActivityMonitor : IDisposable {
 [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint processId);
 [StructLayout(LayoutKind.Sequential)] struct LastInputInfo {public uint Size;public uint Time;}
 [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LastInputInfo info);
 readonly System.Windows.Threading.DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(2)};
 readonly string workerId;
 readonly string file=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"TaskTrack","activity.json");
 ActivityLedger ledger=new(); bool locked;
 public ObservableCollection<AppActivity> Suggestions {get;}=[];
 public string? StorageError {get;private set;}
 public AppActivityMonitor(string workerId){this.workerId=workerId;try{if(File.Exists(file))ledger=JsonSerializer.Deserialize<ActivityLedger>(File.ReadAllText(file))??new();ledger.Finish();}catch(Exception e){StorageError=e.Message;}Refresh();timer.Tick+=(_,_)=>Sample();SystemEvents.SessionSwitch+=SessionChanged;SystemEvents.PowerModeChanged+=PowerChanged;}
 public void SetEnabled(bool value){if(value){Sample();timer.Start();}else{timer.Stop();Flush();}}
 void SessionChanged(object? s,SessionSwitchEventArgs e){if(!timer.Dispatcher.CheckAccess()){timer.Dispatcher.BeginInvoke(new Action(()=>SessionChanged(s,e)));return;}if(e.Reason==SessionSwitchReason.SessionLock||e.Reason==SessionSwitchReason.SessionLogoff){locked=true;Flush();}else if(e.Reason==SessionSwitchReason.SessionUnlock)locked=false;}
 void PowerChanged(object s,PowerModeChangedEventArgs e){if(!timer.Dispatcher.CheckAccess()){timer.Dispatcher.BeginInvoke(new Action(()=>PowerChanged(s,e)));return;}if(e.Mode==PowerModes.Suspend){locked=true;Flush();}else if(e.Mode==PowerModes.Resume)locked=false;}
 void Sample(){
  string? app=null;var last=new LastInputInfo{Size=(uint)Marshal.SizeOf<LastInputInfo>()};
  bool eligible=!locked&&GetLastInputInfo(ref last)&&unchecked((uint)Environment.TickCount-last.Time)<120000;
  if(eligible)try{GetWindowThreadProcessId(GetForegroundWindow(),out var pid);if(pid!=(uint)Environment.ProcessId&&pid!=0){using var p=Process.GetProcessById((int)pid);app=p.ProcessName;}}catch(ArgumentException){}catch(System.ComponentModel.Win32Exception){}catch(InvalidOperationException){}
  ledger.Sample(workerId,app,app,DateTime.UtcNow,eligible&&app!=null);Save();Refresh();
 }
 public void Flush(){ledger.Finish();Save();Refresh();}
 public void Clear(){ledger.Intervals.RemoveAll(x=>x.WorkerId==workerId);ledger.Pending=null;Save();Refresh();}
 void Refresh(){Suggestions.Clear();foreach(var x in ledger.Suggestions(workerId))Suggestions.Add(x);}
 void Save(){try{Directory.CreateDirectory(Path.GetDirectoryName(file)!);var tmp=file+".tmp";File.WriteAllText(tmp,JsonSerializer.Serialize(ledger));File.Move(tmp,file,true);StorageError=null;}catch(Exception e)when(e is IOException or UnauthorizedAccessException){StorageError=e.Message;}}
 public void Dispose(){timer.Stop();Flush();SystemEvents.SessionSwitch-=SessionChanged;SystemEvents.PowerModeChanged-=PowerChanged;}
}
