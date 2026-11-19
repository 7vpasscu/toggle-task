using System.Drawing; using System.Windows; using Forms=System.Windows.Forms;
namespace ToggleTask;
public partial class MainWindow:Window { readonly TimerStore store=new(); readonly Forms.NotifyIcon tray;
 public MainWindow(){InitializeComponent();DataContext=store;tray=new(){Icon=SystemIcons.Application,Text="Toggle Task",Visible=true};tray.DoubleClick+=(_,_)=>{Show();Activate();};Closed+=(_,_)=>{tray.Visible=false;tray.Dispose();store.Dispose();};}
 void Timer_Click(object s,RoutedEventArgs e)=>store.ToggleTimer(); }
