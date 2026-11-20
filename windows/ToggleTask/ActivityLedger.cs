namespace ToggleTask;
public sealed record AppActivity(string Id,string WorkerId,string AppId,string AppName,DateTime Start,DateTime End) {
 public int Seconds=>Math.Max(0,(int)(End-Start).TotalSeconds);
 public string Summary=>$"{AppName} · {Start.ToLocalTime():HH:mm}–{End.ToLocalTime():HH:mm} · {Seconds/60} min";
}
public sealed class ActivityLedger {
 public List<AppActivity> Intervals {get;set;}=[];
 public AppActivity? Pending {get;set;}
 public void Sample(string? workerId,string? appId,string? appName,DateTime now,bool eligible) {
  Intervals.RemoveAll(x=>x.End<now.AddDays(-7));
  if(!eligible||string.IsNullOrWhiteSpace(workerId)||appId is null||appName is null){Finish();return;}
  if(Pending is{} p&&p.WorkerId==workerId&&p.AppId==appId&&now>=p.End&&(now-p.End).TotalSeconds<=10)Pending=p with{End=now};
  else{Finish();Pending=new(Guid.NewGuid().ToString(),workerId,appId,appName,now,now);}
 }
 public void Finish(){if(Pending is{Seconds:>=15} p)Intervals.Add(p);Pending=null;}
 public IEnumerable<AppActivity> Suggestions(string? workerId)=>string.IsNullOrWhiteSpace(workerId)?[]:Intervals.Where(x=>x.WorkerId==workerId).OrderByDescending(x=>x.Start);
}
