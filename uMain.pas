unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, uWorker, Vcl.ComCtrls, Vcl.ExtCtrls;

type
  TForm1 = class( TForm )
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
    Edit2 : TEdit;
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

    procedure PrimeWorkFeedback( Sender : TWorker; FeedValue : TObject );
    procedure PrimeWorkProgress( Sender : TWorker; Progress : integer );

    procedure PrimeWorkFinished( Sender : TWorker;
      FinishedStatus : TWorkerStatus );
    procedure PrimeWorkStarted( Sender : TWorker );

    procedure PrimeWorkFinished8X( Sender : TWorker;
      FinishedStatus : TWorkerStatus );
    procedure PrimeWorkProgress8X( Sender : TWorker; Progress : integer );
  public
    { Public declarations }
  end;

var
  Form1 : TForm1;

implementation

{$R *.DFM}

uses
  uTest;

const
  ThreadCount = 32;

var
  WorkerMgr : TWorkerMgr;
  Worker : TWorker;
  Workers : array [ 0 .. ThreadCount - 1 ] of TWorker;
  pbs : array [ 0 .. ThreadCount - 1 ] of TProgressBar;

procedure TForm1.FormCreate( Sender : TObject );
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

procedure TForm1.FormDestroy( Sender : TObject );
begin
  if Assigned( WorkerMgr ) then
    WorkerMgr.Free;
end;

function TForm1.PrimeWork( Sender : TWorker; Data : TObject ) : TWorkerStatus;
var
  N, M : integer;
  IsPrime : Boolean;
  PrimesFound : integer;
  NumbersToCheck : integer;
  Progress : integer;
  NeedCancel : LongBool;
begin
  NumbersToCheck := integer( Data );
  PrimesFound := 0;

  // Finding prime numbers using a very low tech approach
  for N := 2 to NumbersToCheck - 1 do
  begin
    if Sender.IsSuspendPending then
      Sender.AcceptSuspend;

    NeedCancel := FALSE;
    Sender.NeedCancel( @NeedCancel );
    if Sender.IsCancelPending or NeedCancel then
    begin
      Sender.AcceptCancel( );
      Exit( wsCanceled );
    end;

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
      Sender.FeedbackData( TObject( N ) );
    end;

    Progress := MulDiv( N, 100, NumbersToCheck );
    Sender.FeedbackProgress( Progress );

  end;

  Exit( wsSuccessed );
end;

procedure TForm1.PrimeWorkFinished( Sender : TWorker;
  FinishedStatus : TWorkerStatus );
begin
  Label1.Caption := WorkerStatusText[ FinishedStatus ];
  Label1.Update;
  btnStart.Enabled := True;
  btnCancel.Enabled := FALSE;
  Self.Update;
end;

procedure TForm1.PrimeWorkFinished8X( Sender : TWorker;
  FinishedStatus : TWorkerStatus );
begin
end;

procedure TForm1.PrimeWorkFeedback( Sender : TWorker; FeedValue : TObject );
begin
  edtPrime.Text := IntToStr( integer( FeedValue ) );
  edtPrime.Update;
end;

procedure TForm1.PrimeWorkProgress( Sender : TWorker; Progress : integer );
begin
  ProgressBar1.Position := Progress;
  ProgressBar1.Update;
end;

procedure TForm1.PrimeWorkProgress8X( Sender : TWorker; Progress : integer );
begin
  if Sender.Tag < 8 then
  begin
    pbs[ Sender.Tag ].Position := Progress;
    pbs[ Sender.Tag ].Update;
  end;
  Self.Update;
end;

procedure TForm1.PrimeWorkNeedCancel( Sender : TWorker;
  NeedCancel : PLongBool );
begin
  NeedCancel^ := FALSE;
end;

procedure TForm1.PrimeWorkStarted( Sender : TWorker );
begin
  btnStart.Enabled := FALSE;
  btnCancel.Enabled := True;
end;

var
  globalTimer : integer;

procedure TForm1.Timer1Timer( Sender : TObject );
begin
  Inc( globalTimer );
  Edit1.Text := IntToStr( globalTimer );

end;

procedure TForm1.btnCancelClick( Sender : TObject );
begin
  if Assigned( Worker ) then
    Worker.Cancel;
end;

procedure TForm1.btnStartClick( Sender : TObject );
var
  MaxNum : integer;
begin
  Label1.Caption := 'Executing ...';
  Self.Update;

  MaxNum := StrToInt( edtMaxNum.Text );
  Worker := WorkerMgr.AllocWorker( 'PrimeWork' );
  Worker.OnFeedbackProgress := PrimeWorkProgress;
  Worker.OnFeedbackData := PrimeWorkFeedback;
  Worker.OnStart := PrimeWorkStarted;
  Worker.OnFinish := PrimeWorkFinished;
  Worker.OnNeedCancel := PrimeWorkNeedCancel;
  Worker.Start( PrimeWork, TObject( MaxNum ) );
end;

procedure TForm1.btnCancelAllClick( Sender : TObject );
var
  I : integer;
  ThreadNum : integer;
begin
  ThreadNum := StrToInt( edtThreadNum.Text );
  for I := 0 to ThreadNum - 1 do
  begin
    if Assigned( Workers[ I ] ) then
      Workers[ I ].Cancel( );
  end;
end;

procedure TForm1.btnStartAllClick( Sender : TObject );
var
  ThreadNum : integer;
  MaxNum : integer;
  I : integer;
begin
  MaxNum := StrToInt( edtMaxNum.Text );
  ThreadNum := StrToInt( edtThreadNum.Text );
  // SetLength( Workers, ThreadNum );

  for I := 0 to ThreadNum - 1 do
  begin
    Workers[ I ] := WorkerMgr.AllocWorker( 'PrimeWork ' + IntToStr( I ), I );
    Workers[ I ].OnFeedbackProgress := PrimeWorkProgress8X;
    Workers[ I ].OnFeedbackData := PrimeWorkFeedback;
    Workers[ I ].OnFinish := PrimeWorkFinished8X;
    Workers[ I ].Start( PrimeWork, TObject( MaxNum ) );
  end;

end;

end.
