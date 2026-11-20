using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Runtime.CompilerServices;
using System.Security.Principal;
using System.Text.Json;
namespace ToggleTask;
public sealed class TimerStore : INotifyPropertyChanged, IDisposable {
 readonly System.Windows.Threading.DispatcherTimer timer=new(){Interval=TimeSpan.FromSeconds(1)};
 readonly List<TimeSession> all=[];
 readonly string file=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"TaskTrack","sessions.json");
 TimeSession? active; string selected="job-001",description="",status="Local profile · Notion disconnected";int elapsed;bool manual;DateTime day=DateTime.Today;
 string durationText="00:30",initialDuration="";DateTime? manualDate=DateTime.Today;DateTime originalStart;TimeSpan originalLength;string? editingId;
 public string WorkerId {get;}="local:"+WindowsIdentity.GetCurrent().User!.Value;
 public AppActivityMonitor Activity {get;}
 public IReadOnlyList<Project> Projects {get;}=MockData.Projects;
 public ObservableCollection<TimeSession> Sessions {get;}=[];
 public ObservableCollection<TimeSession> DaySessions {get;}=[];
 public sealed record CalendarBlock(TimeSession Session,double Top,double Height);
 public ObservableCollection<CalendarBlock> DayBlocks {get;}=[];
 public string[] Hours {get;}=Enumerable.Range(0,24).Select(h=>$"{h:00}:00").ToArray();
 public event PropertyChangedEventHandler? PropertyChanged;
 public bool IsRunning=>active!=null;
 public int ElapsedSeconds {get=>elapsed;private set{elapsed=value;Changed();Changed(nameof(FormattedElapsed));}}
 public static string Format(int seconds)=>EntryDuration.Format(seconds);
 public string FormattedElapsed=>Format(elapsed);
 public string TimerButtonText=>ManualMode?"Save":IsRunning?"■":"▶";
 public string SelectedProjectId {get=>selected;set{selected=value;Changed();}}
 public string ActivityDescription {get=>description;set{description=value;Changed();}}
 public string SyncState {get=>status;private set{status=value;Changed();}}
 public bool ManualMode {get=>manual;set{manual=value;Changed();Changed(nameof(TimerButtonText));if(!value)editingId=null;}}
 public DateTime? ManualDate {get=>manualDate;set{manualDate=value;Changed();}}
 public string ManualDuration {get=>durationText;set{durationText=value;Changed();}}
 public DateTime SelectedDay {get=>day;set{day=value.Date;Changed();Refresh();}}
 public string DayTotal=>Format((int)DaySessions.Sum(s=>SessionPolicy.Overlap(s,day,day.AddDays(1))));
 public Project? SelectedProject=>Projects.FirstOrDefault(p=>p.Id==SelectedProjectId);
 public sealed record Snapshot(List<TimeSession> Sessions,TimeSession? Active);
 public TimerStore(){
  Activity=new(WorkerId);
  try{if(File.Exists(file)){var saved=JsonSerializer.Deserialize<Snapshot>(File.ReadAllText(file));if(saved!=null){all.AddRange(saved.Sessions);if(saved.Active?.WorkerId==WorkerId)active=saved.Active;}}}
  catch(Exception e)when(e is IOException or JsonException or UnauthorizedAccessException){SyncState="Could not load your data: "+e.Message;}
  Refresh();timer.Tick+=(_,_)=>{if(active is{} s)ElapsedSeconds=Math.Max(0,(int)(DateTime.Now-s.StartedAt).TotalSeconds);};if(active!=null)timer.Start();
 }
 void Refresh(){Sessions.Clear();foreach(var s in SessionPolicy.Owned(all,WorkerId).OrderByDescending(x=>x.StartedAt))Sessions.Add(s);DaySessions.Clear();DayBlocks.Clear();foreach(var s in Sessions.Where(s=>SessionPolicy.Overlap(s,day,day.AddDays(1))>0)){DaySessions.Add(s);DayBlocks.Add(new(s,Math.Max(0,(s.StartedAt-day).TotalMinutes),Math.Max(12,SessionPolicy.Overlap(s,day,day.AddDays(1))/60)));}Changed(nameof(DayTotal));}
 public void Submit(){if(ManualMode)SaveManual();else ToggleTimer();}
 public void ToggleTimer(){if(IsRunning)StopTimer();else StartTimer();}
 public void StartTimer(){if(IsRunning||SelectedProject is not{} p)return;active=new(Guid.NewGuid().ToString(),p.Id,p.Name,ActivityDescription.Trim(),DateTime.Now,null,0,Environment.UserName,"timer",WorkerId);ElapsedSeconds=0;timer.Start();Changed(nameof(IsRunning));Changed(nameof(TimerButtonText));Persist();}
 public void StopTimer(){if(active is not{} s)return;var end=DateTime.Now;if(end<=s.StartedAt)end=s.StartedAt.AddSeconds(1);if(Save(s with{EndedAt=end,DurationSeconds=Math.Max(1,(int)(end-s.StartedAt).TotalSeconds)})){active=null;timer.Stop();ElapsedSeconds=0;Changed(nameof(IsRunning));Changed(nameof(TimerButtonText));Persist();}}
 public bool Save(TimeSession s){
  if(s.WorkerId!=WorkerId||all.Any(x=>x.Id==s.Id&&x.WorkerId!=WorkerId)){SyncState="This session belongs to another profile.";return false;}
  if(s.EndedAt is not{} end||end<=s.StartedAt||end>DateTime.Now.AddSeconds(1)){SyncState="Check the start and end times. The session must finish by the current time.";return false;}
  if(Sessions.Any(x=>x.Id!=s.Id&&s.StartedAt<x.EndedAt&&end>x.StartedAt)||(active!=null&&active.Id!=s.Id&&end>active.StartedAt)){SyncState="This session overlaps time already logged.";return false;}
  all.RemoveAll(x=>x.Id==s.Id);all.Add(s with{DurationSeconds=(int)(end-s.StartedAt).TotalSeconds});Refresh();Persist();return true;
 }
 public void SaveManual(){
  if(SelectedProject is not{} p || EntryDuration.Minutes(ManualDuration) is not int minutes || ManualDate is not DateTime date){
   SyncState="Select a project and start date. Enter a duration such as 26, 126 or 1:26.";return;
  }
  var now=DateTime.Now;
  var start=editingId!=null ? date.Date+originalStart.TimeOfDay : now.AddMinutes(-minutes);
  if(editingId==null && date.Date!=DateTime.Today) start=date.Date+start.TimeOfDay;
  var length=editingId!=null && ManualDuration==initialDuration?originalLength:TimeSpan.FromMinutes(minutes);
  if(Save(new(editingId??Guid.NewGuid().ToString(),p.Id,p.Name,ActivityDescription,start,start+length,0,Environment.UserName,"manual",WorkerId))){
   editingId=null;ManualDate=DateTime.Today;
  }
 }
 void LoadInterval(string id,string text,DateTime start,DateTime end){
  ManualMode=true;editingId=id;ActivityDescription=text;originalStart=start;originalLength=end-start;
  ManualDate=start.Date;initialDuration=EntryDuration.Format(Math.Max(60,(int)originalLength.TotalSeconds));ManualDuration=initialDuration;
 }
 public void Review(AppActivity item){if(item.WorkerId==WorkerId)LoadInterval("activity-"+item.Id,item.AppName,item.Start.ToLocalTime(),item.End.ToLocalTime());}
 public void Edit(TimeSession s){if(s.WorkerId!=WorkerId)return;SelectedProjectId=s.ProjectId;LoadInterval(s.Id,s.Description,s.StartedAt,s.EndedAt??s.StartedAt);}
 void Persist(){try{Directory.CreateDirectory(Path.GetDirectoryName(file)!);var tmp=file+".tmp";File.WriteAllText(tmp,JsonSerializer.Serialize(new Snapshot(all,active)));File.Move(tmp,file,true);SyncState="Saved locally · Notion disconnected";}catch(Exception e)when(e is IOException or UnauthorizedAccessException){SyncState="Could not save: "+e.Message;}}
 public void Dispose(){timer.Stop();Persist();Activity.Dispose();}
 void Changed([CallerMemberName]string? n=null)=>PropertyChanged?.Invoke(this,new(n));
}
