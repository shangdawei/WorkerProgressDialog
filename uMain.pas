unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, uWorker, Vcl.ComCtrls, Vcl.ExtCtrls;

type
  TfrmMain = class( TForm )
    btnStart: TButton;
    btnCancel: TButton;
    edtMaxNum: TEdit;
    ProgressBar1: TProgressBar;
    ProgressBar2: TProgressBar;
    ProgressBar3: TProgressBar;
    ProgressBar4: TProgressBar;
    ProgressBar5: TProgressBar;
    ProgressBar6: TProgressBar;
    ProgressBar7: TProgressBar;
    ProgressBar8: TProgressBar;
    ProgressBar9: TProgressBar;
    Label1: TLabel;
    edtPrime: TEdit;
    Timer1: TTimer;
    Edit1: TEdit;
    btnSuspend: TButton;
    btnResume: TButton;
    btnStartAll: TButton;
    btnCancelAll: TButton;
    btnSuspendAll: TButton;
    btnResumeAll: TButton;
    cbDlg: TCheckBox;
    procedure FormCreate( Sender: TObject );
    procedure btnStartClick( Sender: TObject );
    procedure btnCancelClick( Sender: TObject );
    procedure Timer1Timer( Sender: TObject );
    procedure btnSuspendClick( Sender: TObject );
    procedure btnResumeClick( Sender: TObject );
    procedure btnStartAllClick( Sender: TObject );
    procedure btnCancelAllClick( Sender: TObject );
    procedure btnSuspendAllClick( Sender: TObject );
    procedure btnResumeAllClick( Sender: TObject );
  private
    { Private declarations }
    function PrimeTask( Sender: TWorker; Data: TObject ): TTaskResult;

    procedure PrimeTaskStateChanged( Sender: TWorker; WorkerState: TTaskState );
    procedure PrimeTaskDataProcessed( Sender: TWorker; FeedId: Integer; FeedValue: TObject );
    procedure PrimeTaskProgressChanged( Sender: TWorker; Progress: Integer );

    procedure PrimeTaskDlgDataProcessed( Sender: TWorker; FeedId: Integer; FeedValue: TObject );
    procedure PrimeTaskDlgProgressChanged( Sender: TWorker; Progress: Integer );
    procedure PrimeTaskDlgStateChanged( Sender: TWorker; WorkerState: TTaskState );

    procedure PrimeTaskStateChanged8X( Sender: TWorker; WorkerState: TTaskState );
    procedure PrimeTaskProgress8X( Sender: TWorker; Progress: Integer );

  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  uProgressDialog;

{$R *.DFM}

const
  ThreadCount = 8;

var
  globalTimer: Integer;

  Worker: TWorker;

  pbs: array [ 0 .. ThreadCount - 1 ] of TProgressBar;
  Workers: array [ 0 .. ThreadCount - 1 ] of TWorker;
  WorkersCompleted: DWORD;

  ProgressDlg: TProgressDialog;

procedure TfrmMain.FormCreate( Sender: TObject );
begin
  TThread.NameThreadForDebugging( 'Main' );
  WorkerMgr := TWorkerMgr.Create;

  pbs[ 0 ] := ProgressBar2;
  pbs[ 1 ] := ProgressBar3;
  pbs[ 2 ] := ProgressBar4;
  pbs[ 3 ] := ProgressBar5;
  pbs[ 4 ] := ProgressBar6;
  pbs[ 5 ] := ProgressBar7;
  pbs[ 6 ] := ProgressBar8;
  pbs[ 7 ] := ProgressBar9;
end;

function TfrmMain.PrimeTask( Sender: TWorker; Data: TObject ): TTaskResult;
var
  N, M: Integer;
  IsPrime: Boolean;
  PrimesFound: Integer;
  NumbersToCheck: Integer;
  Progress: Integer;
begin
  NumbersToCheck := Integer( Data );
  PrimesFound := 0;

  // Finding prime numbers using a very low tech approach
  for N := 2 to NumbersToCheck - 1 do
  begin
    if Sender.IsTaskCancelPending then
      Exit( trCanceled );

    IsPrime := True;
    for M := 2 to N - 1 do
    begin
      if N mod M = 0 then
      begin
        IsPrime := FALSE;
        Break;
      end;
    end;

    if IsPrime then
    begin
      Inc( PrimesFound );
      Sender.TaskDataProcessed( TObject( N ) );
    end;

    Progress := MulDiv( N, 100, NumbersToCheck );
    Sender.TaskProgressChanged( Progress );

  end;

  Exit( trSuccessed );
end;

procedure TfrmMain.PrimeTaskDlgDataProcessed( Sender: TWorker; FeedId: Integer; FeedValue: TObject );
begin
  ProgressDlg.Text1 := ( IntToStr( Integer( FeedValue ) ) );
end;

procedure TfrmMain.PrimeTaskDataProcessed( Sender: TWorker; FeedId: Integer; FeedValue: TObject );
begin
  edtPrime.Text := IntToStr( Integer( FeedValue ) );
  edtPrime.Update;
end;

procedure TfrmMain.PrimeTaskDlgProgressChanged( Sender: TWorker; Progress: Integer );
begin
  ProgressDlg.Pos := Progress;
end;

procedure TfrmMain.PrimeTaskDlgStateChanged( Sender: TWorker; WorkerState: TTaskState );
begin
  if WorkerState = tsCompleted then
  begin
    ProgressDlg.Close( );
  end;
end;

procedure TfrmMain.PrimeTaskProgressChanged( Sender: TWorker; Progress: Integer );
begin
  ProgressBar1.Position := Progress;
  ProgressBar1.Update;
end;

procedure TfrmMain.PrimeTaskStateChanged( Sender: TWorker; WorkerState: TTaskState );
begin
  if WorkerState = tsStarted then
  begin
    btnStart.Enabled := FALSE;
    btnCancel.Enabled := True;
    Label1.Caption := 'Executing ...';
  end else if WorkerState = tsSuspended then
  begin
    Label1.Caption := 'Suspended ...'
  end else if WorkerState = tsResumed then
  begin
    Label1.Caption := 'Executing ...';
  end else if WorkerState = tsCompleted then
  begin
    btnStart.Enabled := True;
    btnCancel.Enabled := FALSE;

    Label1.Caption := WorkerResultText[ Sender.TaskResult ];
    Label1.Update;
  end;
end;

procedure TfrmMain.Timer1Timer( Sender: TObject );
begin
  Inc( globalTimer );
  Edit1.Text := IntToStr( globalTimer );
end;

procedure TfrmMain.btnStartAllClick( Sender: TObject );
var
  ThreadNum: Integer;
  MaxNum: Integer;
  I: Integer;
begin
  MaxNum := StrToInt( edtMaxNum.Text );
  ThreadNum := ThreadCount;
  WorkersCompleted := 0;

  for I := 0 to ThreadNum - 1 do
  begin
    pbs[ I ].Position := 0;
    Workers[ I ] := WorkerMgr.AllocWorker( 'PrimeTask ' + IntToStr( I ), I );
    Workers[ I ].OnTaskProgressChanged := PrimeTaskProgress8X;
    Workers[ I ].OnTaskStateChanged := PrimeTaskStateChanged8X;

    Workers[ I ].TaskStart( PrimeTask, TObject( MaxNum ) );
  end;
end;

procedure TfrmMain.btnStartClick( Sender: TObject );
var
  NumbersToCheck: Integer;
begin
  NumbersToCheck := StrToInt( edtMaxNum.Text );
  Worker := WorkerMgr.AllocWorker( 'PrimeTask' );

  if cbDlg.Checked then
  begin
    ProgressDlg := TProgressDialog.Create( Self, Worker );
    try
      Worker.TaskProc := PrimeTask;
      Worker.TaskParam := TObject( NumbersToCheck );
      Worker.OnTaskStateChanged := PrimeTaskDlgStateChanged;
      Worker.OnTaskProgressChanged := PrimeTaskDlgProgressChanged;
      Worker.OnTaskDataProcessed := PrimeTaskDlgDataProcessed;

      ProgressDlg.Title := Application.Title;
      ProgressDlg.Text0 := 'Finding prime ....';

      ProgressDlg.Min := 0;
      ProgressDlg.Pos := 0;
      ProgressDlg.Max := ( NumbersToCheck + 99 ) div 100;

      ProgressDlg.ShowModal( );
    finally
      ProgressDlg.Free;
    end;
  end else begin
    ProgressBar1.Min := 0;
    ProgressBar1.Max := NumbersToCheck;

    Worker.OnTaskDataProcessed := PrimeTaskDataProcessed;
    Worker.OnTaskStateChanged := PrimeTaskStateChanged;
    Worker.OnTaskProgressChanged := PrimeTaskProgressChanged;
    Worker.TaskStart( PrimeTask, TObject( NumbersToCheck ) );
  end;
end;

procedure TfrmMain.btnSuspendClick( Sender: TObject );
begin
  if Assigned( Worker ) then
    Worker.TaskSuspend;
end;

procedure TfrmMain.btnResumeClick( Sender: TObject );
begin
  Worker.TaskResume;
end;

procedure TfrmMain.btnCancelClick( Sender: TObject );
begin
  if Assigned( Worker ) then
    Worker.TaskCancel;
end;

procedure TfrmMain.PrimeTaskProgress8X( Sender: TWorker; Progress: Integer );
begin
  if Sender.Tag < 8 then
  begin
    pbs[ Sender.Tag ].Position := Progress;
    pbs[ Sender.Tag ].Update;
  end;
end;

procedure TfrmMain.PrimeTaskStateChanged8X( Sender: TWorker; WorkerState: TTaskState );
begin
  if WorkerState = tsStarted then
  begin
    btnStartAll.Enabled := FALSE;
    btnCancelAll.Enabled := True;
  end else if WorkerState = tsCompleted then
  begin
    WorkersCompleted := WorkersCompleted or ( 1 shl ( Sender.Tag ) );
    if WorkersCompleted = $FF then
    begin
      btnStartAll.Enabled := True;
      btnCancelAll.Enabled := FALSE;
    end;
  end;
end;

procedure TfrmMain.btnSuspendAllClick( Sender: TObject );
var
  I: Integer;
begin
  for I := 0 to ThreadCount - 1 do
  begin
    if Workers[ I ].TaskRunning then
      Workers[ I ].TaskSuspend( );
  end;
end;

procedure TfrmMain.btnResumeAllClick( Sender: TObject );
var
  I: Integer;
begin
  for I := 0 to ThreadCount - 1 do
  begin
    if Workers[ I ].TaskRunning then
      Workers[ I ].TaskResume( );
  end;
end;

procedure TfrmMain.btnCancelAllClick( Sender: TObject );
var
  I: Integer;
begin
  for I := 0 to ThreadCount - 1 do
  begin
    if Workers[ I ].TaskRunning then
      Workers[ I ].TaskCancel( );
  end;
end;

end.
