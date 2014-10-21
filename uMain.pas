unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, uWorker, Vcl.ComCtrls, Vcl.ExtCtrls;

type
  TfrmMain = class( TForm )
    btnStart : TButton;
    btnCancel : TButton;
    edtMaxNum : TEdit;
    ProgressBar1 : TProgressBar;
    Label1 : TLabel;
    edtPrime : TEdit;
    btnStartAll : TButton;
    btnCancelAll : TButton;
    ProgressBar2 : TProgressBar;
    ProgressBar3 : TProgressBar;
    ProgressBar4 : TProgressBar;
    ProgressBar5 : TProgressBar;
    ProgressBar6 : TProgressBar;
    ProgressBar7 : TProgressBar;
    ProgressBar8 : TProgressBar;
    ProgressBar9 : TProgressBar;
    edtThreadNum : TEdit;
    Timer1 : TTimer;
    Edit1 : TEdit;
    chkUpdate : TCheckBox;
    procedure FormCreate( Sender : TObject );
    procedure FormDestroy( Sender : TObject );
    procedure btnStartClick( Sender : TObject );
    procedure btnCancelClick( Sender : TObject );
    procedure btnStartAllClick( Sender : TObject );
    procedure btnCancelAllClick( Sender : TObject );
    procedure Timer1Timer( Sender : TObject );
  private
    { Private declarations }
    function PrimeWork( Sender : TWorker; Data : TObject ) : TWorkerStatus;

    procedure PrimeWorkNeedCancel( Sender : TWorker; NeedCancel : PLongBool );

    procedure PrimeWorkData( Sender : TWorker; FeedId : Integer;
      FeedValue : TObject );
    procedure PrimeWorkProgress( Sender : TWorker; Progress : Integer );

    procedure PrimeWorkFinished( Sender : TWorker;
      FinishedStatus : TWorkerStatus );
    procedure PrimeWorkStarted( Sender : TWorker );

    procedure PrimeWorkFinished8X( Sender : TWorker;
      FinishedStatus : TWorkerStatus );
    procedure PrimeWorkProgress8X( Sender : TWorker; Progress : Integer );
  public
    { Public declarations }
  end;

var
  frmMain : TfrmMain;

implementation

{$R *.DFM}

const
  ThreadCount = 32;

var
  WorkerMgr : TWorkerMgr;
  Worker : TWorker;
  Workers : array [ 0 .. ThreadCount - 1 ] of TWorker;
  pbs : array [ 0 .. ThreadCount - 1 ] of TProgressBar;

procedure TfrmMain.FormCreate( Sender : TObject );
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

procedure TfrmMain.FormDestroy( Sender : TObject );
begin
  if Assigned( WorkerMgr ) then
    WorkerMgr.Free;
end;

function TfrmMain.PrimeWork( Sender : TWorker; Data : TObject ) : TWorkerStatus;
var
  N, M : Integer;
  IsPrime : Boolean;
  PrimesFound : Integer;
  NumbersToCheck : Integer;
  Progress : Integer;
begin
  NumbersToCheck := Integer( Data );
  PrimesFound := 0;

  // Finding prime numbers using a very low tech approach
  for N := 2 to NumbersToCheck - 1 do
  begin
    if Sender.IsCancelPending then
      Exit( wsCanceled );

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
      Sender.Data( 0, TObject( N ) );
    end;

    Progress := MulDiv( N, 100, NumbersToCheck );
    Sender.Progress( Progress );

  end;

  Exit( wsSuccessed );
end;

procedure TfrmMain.PrimeWorkFinished( Sender : TWorker;
  FinishedStatus : TWorkerStatus );
begin
  Label1.Caption := WorkerStatusText[ FinishedStatus ];
  Label1.Update;
  btnStart.Enabled := True;
  btnCancel.Enabled := FALSE;
  Self.Update;
end;

procedure TfrmMain.PrimeWorkFinished8X( Sender : TWorker;
  FinishedStatus : TWorkerStatus );
begin
  if Sender.Tag < 8 then
  begin
    pbs[ Sender.Tag ].Position := 100;
    pbs[ Sender.Tag ].Update;
  end;
end;

procedure TfrmMain.PrimeWorkData( Sender : TWorker; FeedId : Integer;
  FeedValue : TObject );
begin
  edtPrime.Text := IntToStr( Integer( FeedValue ) );
  edtPrime.Update;
end;

procedure TfrmMain.PrimeWorkProgress( Sender : TWorker; Progress : Integer );
begin
  ProgressBar1.Position := Progress;
  ProgressBar1.Update;
end;

procedure TfrmMain.PrimeWorkProgress8X( Sender : TWorker; Progress : Integer );
begin
  if Sender.Tag < 8 then
  begin
    pbs[ Sender.Tag ].Position := Progress;
    pbs[ Sender.Tag ].Update;
  end;
  Self.Update;
end;

procedure TfrmMain.PrimeWorkNeedCancel( Sender : TWorker;
  NeedCancel : PLongBool );
begin
  NeedCancel^ := FALSE;
end;

procedure TfrmMain.PrimeWorkStarted( Sender : TWorker );
begin
  btnStart.Enabled := FALSE;
  btnCancel.Enabled := True;
end;

var
  globalTimer : Integer;

procedure TfrmMain.Timer1Timer( Sender : TObject );
begin
  Inc( globalTimer );
  Edit1.Text := IntToStr( globalTimer );

end;

procedure TfrmMain.btnCancelClick( Sender : TObject );
begin
  if Assigned( Worker ) then
    Worker.Cancel;
end;

procedure TfrmMain.btnStartClick( Sender : TObject );
var
  MaxNum : Integer;
begin
  Label1.Caption := 'Executing ...';
  Self.Update;

  MaxNum := StrToInt( edtMaxNum.Text );
  Worker := WorkerMgr.AllocWorker( True, 'PrimeWork' );
  Worker.OnProgress := PrimeWorkProgress;
  Worker.OnData := PrimeWorkData;
  Worker.OnStart := PrimeWorkStarted;
  Worker.OnDone := PrimeWorkFinished;
  Worker.OnNeedCancel := PrimeWorkNeedCancel;
  Worker.Start( PrimeWork, TObject( MaxNum ) );
end;

procedure TfrmMain.btnCancelAllClick( Sender : TObject );
var
  I : Integer;
  ThreadNum : Integer;
begin
  ThreadNum := StrToInt( edtThreadNum.Text );
  for I := 0 to ThreadNum - 1 do
  begin
    if Assigned( Workers[ I ] ) then
      Workers[ I ].Cancel( );
  end;
end;

procedure TfrmMain.btnStartAllClick( Sender : TObject );
var
  ThreadNum : Integer;
  MaxNum : Integer;
  I : Integer;
begin
  MaxNum := StrToInt( edtMaxNum.Text );
  ThreadNum := StrToInt( edtThreadNum.Text );
  // SetLength( Workers, ThreadNum );

  for I := 0 to ThreadNum - 1 do
  begin
    pbs[ I ].Position := 0;
    Workers[ I ] := WorkerMgr.AllocWorker( True,
      'PrimeWork ' + IntToStr( I ), I );
    if chkUpdate.Checked then
    begin
      Workers[ I ].OnProgress := PrimeWorkProgress8X;
      Workers[ I ].OnData := PrimeWorkData;
    end;
    Workers[ I ].OnDone := PrimeWorkFinished8X;
    Workers[ I ].Start( PrimeWork, TObject( MaxNum ) );
  end;

end;

end.
