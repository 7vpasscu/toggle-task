namespace ToggleTask;
public enum ProjectStatus { Pending, Active, Closed }
public sealed record Project(string Id,string Name,string Client,string Area,ProjectStatus Status,int HistoricalMinutes,string[] Participants,string[] WorkTypes);
public sealed record TimeSession(string Id,string ProjectId,string ProjectName,string Description,DateTime StartedAt,DateTime? EndedAt,int DurationSeconds,string RecordedBy,string Source,string? WorkerId=null) { public string DedupeKey => Id; public string DurationLabel => EntryDuration.Format(DurationSeconds); }
public static class SessionPolicy {
 public static IEnumerable<TimeSession> Owned(IEnumerable<TimeSession> sessions,string? workerId) => string.IsNullOrWhiteSpace(workerId) ? [] : sessions.Where(s=>s.WorkerId==workerId);
 public static double Overlap(TimeSession s,DateTime start,DateTime end) => Math.Max(0,(new[]{s.EndedAt??s.StartedAt,end}.Min()-new[]{s.StartedAt,start}.Max()).TotalSeconds);
}
public static class MockData { public static readonly IReadOnlyList<Project> Projects = [new("job-001","Carolina Herrera — Good Girl","Carolina Herrera","Good Girl",ProjectStatus.Active,1420,["Javier","Carla"],["Visuals","Final artwork"]),new("job-002","Rabanne — Christmas 2026","Rabanne","XMAS",ProjectStatus.Pending,860,["Nidia"],["Proposals"]),new("job-003","L’Artisan Parfumeur — Gifting","L’Artisan Parfumeur","Gifting",ProjectStatus.Active,430,["Javier","Paula"],["Visuals"])]; }

public static class EntryDuration {
 public static int? Minutes(string raw) {
  var text=raw.Trim();
  if(System.Text.RegularExpressions.Regex.IsMatch(text, @"^[0-9]{1,2}$")){
   int shortMinutes=int.Parse(text);return shortMinutes>0?shortMinutes:null;
  }
  if(!System.Text.RegularExpressions.Regex.IsMatch(text, @"^[0-9]{1,4}:?[0-5][0-9]$"))return null;
  var digits=text.Replace(":","");
  int total=int.Parse(digits[..^2])*60+int.Parse(digits[^2..]);
  return total is >0 and <=100000?total:null;
 }
 public static string Format(int seconds){
  int minutes=(int)Math.Round(Math.Max(0,seconds)/60.0,MidpointRounding.AwayFromZero);
  return $"{minutes/60:00}:{minutes%60:00}";
 }
}
