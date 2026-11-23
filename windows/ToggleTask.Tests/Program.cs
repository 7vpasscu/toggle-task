using ToggleTask;
static void Check(bool condition,string message){if(!condition)throw new Exception(message);}
var now=DateTime.UtcNow;
var mine=new TimeSession("s","p","P","",now.AddMinutes(-1),now,60,"Integration bot","notion","alice");
var other=mine with{Id="other",WorkerId="bob"};var unassigned=mine with{Id="unassigned",WorkerId=null};
Check(SessionPolicy.Owned([mine,other,unassigned],"alice").Count()==1,"Owner filter");
Check(!SessionPolicy.Owned([mine,other,unassigned],null).Any(),"Missing identity must be empty");
var ledger=new ActivityLedger();
for(int t=0;t<=20;t+=2)ledger.Sample("alice","editor","Editor",now.AddSeconds(t),true);
ledger.Sample("bob","editor","Editor",now.AddSeconds(22),true);
ledger.Sample("bob","editor","Editor",now.AddSeconds(500),true);
ledger.Sample("bob",null,null,now.AddSeconds(502),false);
Check(ledger.Suggestions("alice").Single().Seconds==20,"Observed interval only");
Check(!ledger.Suggestions("bob").Any(),"Do not bridge sleep gaps or worker boundaries");
Check(ledger.Pending==null,"Inactive stops sampling");
Check(EntryDuration.Minutes("26")==26 && EntryDuration.Minutes("126")==86 && EntryDuration.Minutes("1:26")==86,"Compact duration");
Check(EntryDuration.Minutes("160")==null && EntryDuration.Minutes("0")==null,"Invalid duration");
var folder=Directory.CreateTempSubdirectory("task-track-csv-test-");
var csvPath=Path.Combine(folder.FullName,"task-track.csv");
var database=new LocalCsvStore(csvPath);
var csvEntry=mine with { ProjectId=MockData.Projects[0].Id, EndedAt=now, Description="A, \"quoted\"\nactivity", WorkType="Layout", Units=2 };
try{
 database.Write(new(MockData.Projects,[csvEntry],null,"alice"));
 var reopened=new LocalCsvStore(csvPath).Read()!;
 Check(reopened.Sessions.Single().WorkerId=="alice" && reopened.Sessions[0].Description==csvEntry.Description,"CSV session round trip");
 Check(reopened.Sessions[0].Units==2 && reopened.Projects[0].Client==MockData.Projects[0].Client,"CSV project and units");
 database.Write(new(MockData.Projects,[],csvEntry with {EndedAt=null},"alice"));
 Check(new LocalCsvStore(csvPath).Read()!.Active?.Id==csvEntry.Id,"CSV running timer");
 File.WriteAllText(csvPath,"broken");
 bool protectedFile=false;
 try {database.Write(reopened);} catch(IOException){protectedFile=true;}
 Check(protectedFile && File.ReadAllText(csvPath)=="broken","Externally modified CSV protected");
}finally{folder.Delete(true);}
Console.WriteLine("All checks passed.");
