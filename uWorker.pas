unit uWorker;

interface

uses
  System.Classes, System.SysUtils, System.Generics.Defaults,
  System.Generics.Collections, Controls, Forms, Winapi.Windows, Winapi.Messages;

const
  WM_WORKER_STARTED = WM_USER + 100;
  WM_WORKER_SUSPENDED = WM_USER + 101;
  WM_WORKER_RESUMED = WM_USER + 102;
  WM_WORKER_FINISHED = WM_USER + 103;

  WM_WORKER_FEEDBACK_PROGRESS = WM_USER + 105;
  WM_WORKER_FEEDBACK_DATA = WM_USER + 106;

  WM_WORKER_NEED_CANCEL = WM_USER + 107;
  WM_WORKER_NEED_SUSPEND = WM_USER + 108;

type
  TWorkerStatus = ( wsCanceled, wsSuccessed, wsFailed );
  // TWorkerEvent = ( weTerminate, weStart, weResume, weDone );

const
  WorkerStatusText : array [ wsCanceled .. wsFailed ] of string = ( 'Canceled',
    'Successed', 'Failed' );

type
  TWorker = class;

  TWorkerMgr = class;

  TWorkerProc = function( Worker : TWorker; Param : TObject )
    : TWorkerStatus of object;

  PWorkerDataRec = ^TWorkerDataRec;

  TWorkerDataRec = record
    Id : Integer;
    Data : TObject;
  end;

  TWorkerDataEvent = procedure( Sender : TWorker; Id : Integer; Data : TObject )
    of object;

  TWorkerProgressEvent = procedure( Sender : TWorker; Progress : Integer )
    of object;

  TWorkerDoneEvent = procedure( Sender : TWorker; Status : TWorkerStatus )
    of object;

  TCallbackEvent = procedure( Sender : TWorker; Param : PLongBool ) of object;

  TWorkerStateEvent = procedure( Sender : TWorker ) of object;

  TWorkerClass = class of TWorker;

  TWorker = class( TThread )
    FName : string;
    FTag : Integer;
    FOwner : TWorkerMgr;
    FFreeOnDone : LongBool;

    FProc : TWorkerProc;
    FParam : TObject;

    FAlloced : LongBool;
    FExecuting : LongBool;

    FWorking : LongBool;
    FCancelPending : LongBool;

    FSuspended : LongBool;
    FSuspendPending : LongBool;

    FOnNeedCancel : TCallbackEvent;
    FOnNeedSuspend : TCallbackEvent;

    FOnData : TWorkerDataEvent;
    FOnProgress : TWorkerProgressEvent;

    FOnStart : TWorkerStateEvent;
    FOnSuspend : TWorkerStateEvent;
    FOnResume : TWorkerStateEvent;
    FOnDone : TWorkerDoneEvent;

    FTerminateEvent : THandle;
    FStartEvent : THandle;
    FResumeEvent : THandle;
    FDoneEvent : THandle;

    procedure AfterConstruction; override;

  protected
    procedure Execute; override;

    procedure DoData( WorkerDataRec : PWorkerDataRec );
    procedure DoProgress( Progress : Integer );

    procedure DoStarted( );
    procedure DoSuspended( );
    procedure DoResumed( );
    procedure DoDone( Status : TWorkerStatus );

    procedure DoNeedCancel( Cancel : PLongBool );
    procedure DoNeedSuspend( Suspend : PLongBool );

  public
    constructor Create( Owner : TWorkerMgr; Name : string = 'Worker';
      Tag : Integer = 0 );
    destructor Destroy; override;

    // For Main Thread
    procedure Start( Proc : TWorkerProc; Param : TObject );
    procedure Suspend( );
    procedure Resume( );
    procedure Cancel( );

    // For Worker Thread
    function IsCancelPending : LongBool;

    procedure Started( );
    procedure Resumed( );
    procedure Suspended( );
    procedure Done( Status : TWorkerStatus );

    procedure NeedCancel( Cancel : PLongBool );
    procedure NeedSuspend( Suspend : PLongBool );

    procedure Progress( Perent : Integer );
    procedure Data( Id : Integer; Data : TObject );

    // For Main Thread
    property name : string read FName write FName;
    property Tag : Integer read FTag write FTag default 0;
    property Executing : LongBool read FExecuting;
    property Working : LongBool read FWorking;

    property OnStart : TWorkerStateEvent read FOnStart write FOnStart;
    property OnSuspend : TWorkerStateEvent read FOnSuspend write FOnSuspend;
    property OnResume : TWorkerStateEvent read FOnResume write FOnResume;
    property OnDone : TWorkerDoneEvent read FOnDone write FOnDone;

    property OnProgress : TWorkerProgressEvent read FOnProgress
      write FOnProgress;
    property OnData : TWorkerDataEvent read FOnData write FOnData;

    property OnNeedCancel : TCallbackEvent read FOnNeedCancel
      write FOnNeedCancel;
    property OnNeedSuspend : TCallbackEvent read FOnNeedSuspend
      write FOnNeedSuspend;
  end;

  EWorkerMgr = class( Exception );

  TWorkerMgr = class( TThread )
  private
    FName : string;
    FCreated : Boolean;

    FThreadWindow : HWND;
    FProcessWindow : HWND;
    FReadyEvent : THandle;
    FException : Exception;

    FWorkerList : TThreadList< TWorker >;

    procedure TerminatedSet; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    function PostThreadMessage( Msg, WParam, LParam : NativeUInt ) : LongBool;
    function SendThreadMessage( Msg, WParam, LParam : NativeUInt ) : NativeInt;

    function PostProcessMessage( Msg, WParam, LParam : NativeUInt ) : LongBool;
    function SendProcessMessage( Msg, WParam, LParam : NativeUInt ) : NativeInt;

    procedure CreateThreadWindow;
    procedure DeleteThreadWindow;
    procedure ThreadWndMethod( var Msg : TMessage );

    procedure CreateProcessWindow;
    procedure DeleteProcessWindow;
    procedure ProcessWndMethod( var Msg : TMessage );

    procedure HandleException;
    procedure HandleExceptionProcesshronized;

    { doesn't use }
    procedure CreateProcessWindowEx;
    procedure ProcessWndMethodEx( var Msg : TMessage );
    procedure ProcessWndMessageEx( var Msg : TMessage ); message WM_USER;
    { doesn't use }

    procedure Execute; override;
    procedure Idle;

  public
    constructor Create( Name : string = 'WorkerMgr' );
    destructor Destroy; override;

    function AllocWorker( FreeOnDone : LongBool = True;
      Name : string = 'Worker'; Tag : Integer = 0 ) : TWorker;
    procedure FreeWorker( Worker : TWorker );
  end;

var
  WorkerMgr : TWorkerMgr;

implementation

{ TWorker }

const
  WM_TERMINATE_WORKER_MGR = WM_APP;

procedure DeallocateHWnd( Wnd : HWND );
var
  Instance : Pointer;
begin
  Instance := Pointer( GetWindowLong( Wnd, GWL_WNDPROC ) );
  if Instance <> @DefWindowProc then
  begin
    { make sure we restore the default windows procedure before freeing memory }
    SetWindowLong( Wnd, GWL_WNDPROC, Longint( @DefWindowProc ) );
    FreeObjectInstance( Instance );
  end;
  DestroyWindow( Wnd );
end;

procedure TWorker.NeedCancel( Cancel : PLongBool );
begin
  if Assigned( FOnNeedCancel ) then
    FOwner.SendProcessMessage( WM_WORKER_NEED_CANCEL, NativeUInt( Self ),
      NativeUInt( Cancel ) );
end;

procedure TWorker.NeedSuspend( Suspend : PLongBool );
begin
  if Assigned( FOnNeedSuspend ) then
    FOwner.SendProcessMessage( WM_WORKER_NEED_SUSPEND, NativeUInt( Self ),
      NativeUInt( Suspend ) );
end;

procedure TWorker.Data( Id : Integer; Data : TObject );
var
  WorkerDataRec : PWorkerDataRec;
begin
  if Assigned( FOnData ) then
  begin
    New( WorkerDataRec );

    WorkerDataRec.Id := Id;
    WorkerDataRec.Data := Data;
    FOwner.SendProcessMessage( WM_WORKER_FEEDBACK_DATA, NativeUInt( Self ),
      NativeUInt( WorkerDataRec ) );

    Dispose( WorkerDataRec );
  end;
end;

procedure TWorker.Progress( Perent : Integer );
begin
  if Assigned( FOnProgress ) then
    FOwner.SendProcessMessage( WM_WORKER_FEEDBACK_PROGRESS, NativeUInt( Self ),
      NativeUInt( Perent ) )
end;

procedure TWorker.Started;
begin
  FCancelPending := FALSE;
  FSuspendPending := FALSE;

  if Assigned( FOnStart ) then
    FOwner.PostProcessMessage( WM_WORKER_STARTED, NativeUInt( Self ),
      NativeUInt( 0 ) )
end;

procedure TWorker.Resumed;
begin
  if Assigned( FOnResume ) then
    FOwner.PostProcessMessage( WM_WORKER_RESUMED, NativeUInt( Self ),
      NativeUInt( 0 ) )
end;

procedure TWorker.Suspended( );
begin
  if Assigned( FOnSuspend ) then
    FOwner.PostProcessMessage( WM_WORKER_SUSPENDED, NativeUInt( Self ),
      NativeUInt( 0 ) )
end;

procedure TWorker.Done( Status : TWorkerStatus );
begin
  FCancelPending := FALSE;
  FSuspendPending := FALSE;

  FOwner.SendProcessMessage( WM_WORKER_FINISHED, NativeUInt( Self ),
    NativeUInt( Status ) );

  if FDoneEvent <> 0 then
    SetEvent( FDoneEvent );
end;

procedure TWorker.Suspend;
begin
  if FWorking and not FSuspended then
    FSuspendPending := True;
end;

procedure TWorker.Resume;
begin
  if FWorking and FSuspended then
    SetEvent( FResumeEvent );
end;

procedure TWorker.Cancel;
var
  Wait : DWORD;
begin
  if FWorking then
  begin
    FCancelPending := True;
    Resume;

    FDoneEvent := CreateEvent( nil, True, FALSE, '' );

    while True do
    begin
      Wait := MsgWaitForMultipleObjects( 1, FDoneEvent, FALSE, INFINITE,
        QS_ALLINPUT );

      if Wait = WAIT_OBJECT_0 then
      begin
        ResetEvent( FDoneEvent );
        CloseHandle( FDoneEvent );
        Exit;
      end;
      Application.ProcessMessages
    end;
  end;
end;

procedure TWorker.Start( Proc : TWorkerProc; Param : TObject );
begin
  Self.FProc := Proc;
  Self.FParam := Param;
  while not FExecuting do
    Yield;

  SetEvent( Self.FStartEvent );
end;

constructor TWorker.Create( Owner : TWorkerMgr; Name : string; Tag : Integer );
begin
  FName := name;
  FTag := Tag;
  FOwner := Owner;

  inherited Create( FALSE );
end;

procedure TWorker.AfterConstruction;
begin
  inherited AfterConstruction; // ResumeThread

  while not FExecuting do // Wait for thread execute
    Yield; // Suspend Caller's Thread, to start Worker's Thread
end;

procedure TWorker.Execute;
var
  Wait : DWORD;
  Status : TWorkerStatus;
  FEvents : array [ 0 .. 1 ] of THandle;
begin
  NameThreadForDebugging( FName );

  FTerminateEvent := CreateEvent( nil, True, FALSE, '' );
  FStartEvent := CreateEvent( nil, True, FALSE, '' );
  FEvents[ 0 ] := FTerminateEvent;
  FEvents[ 1 ] := FStartEvent;

  FWorking := FALSE;
  FExecuting := True;

  try
    while not Terminated do
    begin
      Wait := WaitForMultipleObjects( 2, @FEvents, FALSE, INFINITE );
      // If more than one object became signaled during the call,
      // this is the array index of the signaled object
      // with the smallest index value of all the signaled objects.
      case Wait of
        WAIT_OBJECT_0 .. WAIT_OBJECT_0 + 1 :
          if WAIT_OBJECT_0 = Wait then // weTerminate
          begin
            ResetEvent( FTerminateEvent );
            Exit;
          end else begin
            ResetEvent( FStartEvent );

            FWorking := True;
            Started( );
            Status := FProc( Self, FParam );
            Done( Status ); // wsCanceled, wsSuccessed, wscFailed
            FWorking := FALSE;
          end;

        WAIT_ABANDONED_0 .. WAIT_ABANDONED_0 + 1 :
          begin
            // mutex object abandoned
          end;

        WAIT_FAILED :
          begin
            if GetLastError <> ERROR_INVALID_HANDLE then
            begin
              // the wait failed because of something other than an invalid handle
              RaiseLastOSError;
            end else begin
              // at least one handle has become invalid outside the wait call
            end;
          end;

        WAIT_TIMEOUT :
          begin
            // Never because dwMilliseconds is INFINITE
          end;
      else
        begin

        end;
      end;
    end;

  finally
    if FTerminateEvent <> 0 then
      CloseHandle( FTerminateEvent );

    if FStartEvent <> 0 then
      CloseHandle( FStartEvent );

    FExecuting := FALSE;
  end;
end;

function TWorker.IsCancelPending : LongBool;
var
  NeedCancel : LongBool;
  NeedSuspend : LongBool;
begin
  Result := FSuspendPending;
  if not Result then
  begin
    NeedSuspend := FALSE;
    Self.NeedSuspend( @NeedSuspend );
    Result := NeedSuspend;
  end;

  if Result then
  begin
    FSuspendPending := FALSE;
    FSuspended := True;
    Suspended( );

    FResumeEvent := CreateEvent( nil, True, FALSE, '' );
    WaitForSingleObject( FResumeEvent, INFINITE );
    ResetEvent( FResumeEvent );
    CloseHandle( FResumeEvent );

    FSuspended := FALSE;
    Resumed( );
  end;

  Result := FCancelPending;
  if not Result then
  begin
    NeedCancel := FALSE;
    Self.NeedCancel( @NeedCancel );
    Result := NeedCancel;
  end;

  if Result then
    FCancelPending := FALSE;
end;

destructor TWorker.Destroy;
begin
  if FExecuting then
  begin
    if not FWorking then // Wait for StartEvent or ExitEvent
    begin
      SetEvent( FTerminateEvent );
    end else begin
      Cancel;
    end;
  end;

  inherited Destroy;
end;

procedure TWorker.DoData( WorkerDataRec : PWorkerDataRec );
begin
  if Assigned( FOnData ) then
  begin
    FOnData( Self, WorkerDataRec.Id, WorkerDataRec.Data );
  end;
end;

procedure TWorker.DoProgress( Progress : Integer );
begin
  if Assigned( FOnProgress ) then
    FOnProgress( Self, Progress );
end;

procedure TWorker.DoDone( Status : TWorkerStatus );
begin
  if Assigned( FOnDone ) then
    FOnDone( Self, Status );

  if Self.FFreeOnDone then
    FOwner.FreeWorker( Self );
end;

procedure TWorker.DoResumed;
begin
  if Assigned( FOnResume ) then
    FOnResume( Self );
end;

procedure TWorker.DoStarted;
begin
  if Assigned( FOnStart ) then
    FOnStart( Self );
end;

procedure TWorker.DoSuspended;
begin
  if Assigned( FOnSuspend ) then
    FOnSuspend( Self );
end;

procedure TWorker.DoNeedCancel( Cancel : PLongBool );
begin
  Cancel^ := FALSE;
  if Assigned( FOnNeedCancel ) then
    FOnNeedCancel( Self, Cancel );
end;

procedure TWorker.DoNeedSuspend( Suspend : PLongBool );
begin
  Suspend^ := FALSE;
  if Assigned( FOnNeedSuspend ) then
    FOnNeedSuspend( Self, Suspend );
end;

{ TWorkerMgr }

procedure TWorkerMgr.CreateProcessWindow;
begin
  FProcessWindow := AllocateHWnd( ProcessWndMethod );
end;

procedure TWorkerMgr.CreateThreadWindow;
begin
  FThreadWindow := AllocateHWnd( ThreadWndMethod );
end;

function TWorkerMgr.AllocWorker( FreeOnDone : LongBool; Name : string;
  Tag : Integer ) : TWorker;
var
  I : Integer;
  UnallocedWorkerFound : LongBool;
begin
  UnallocedWorkerFound := FALSE;
  for I := 0 to FWorkerList.LockList.Count - 1 do
  begin
    Result := FWorkerList.LockList[ I ];
    if not Result.FAlloced then
    begin
      UnallocedWorkerFound := True;
      Break;
    end;
  end;

  if not UnallocedWorkerFound then
  begin
    if FWorkerList.LockList.Count = 32 then
      raise EWorkerMgr.Create( 'Can not create worker thread.' );

    Result := TWorker.Create( Self, name );

    FWorkerList.Add( Result );
  end;

  Result.FAlloced := True;

  Result.Name := name;
  Result.Tag := Tag;
  Result.FFreeOnDone := FreeOnDone;

  Result.OnStart := nil;
  Result.OnSuspend := nil;
  Result.OnResume := nil;
  Result.OnDone := nil;

  Result.OnProgress := nil;
  Result.OnData := nil;

  Result.OnNeedCancel := nil;
  Result.OnNeedSuspend := nil;
end;

procedure TWorkerMgr.FreeWorker( Worker : TWorker );
var
  I : Integer;
begin
  for I := 0 to FWorkerList.LockList.Count - 1 do
  begin
    if Worker = FWorkerList.LockList[ I ] then
    begin
      Worker.FAlloced := FALSE;
      Worker := nil;
      Exit;
    end;
  end;
end;

procedure TWorkerMgr.HandleExceptionProcesshronized;
begin
  if FException is Exception then
    Application.ShowException( FException )
  else
    System.SysUtils.ShowException( FException, nil );
end;

procedure TWorkerMgr.ThreadWndMethod( var Msg : TMessage );
var
  Handled : Boolean;
  Worker : TWorker;
begin
  Handled := True; // Assume we handle message

  Worker := TWorker( Msg.WParam );

  case Msg.Msg of

    WM_TERMINATE_WORKER_MGR :
      begin
        PostQuitMessage( 0 );
      end;

  else
    Handled := FALSE; // We didn't handle message
  end;

  if Handled then // We handled message - record in message result
    Msg.Result := 0
  else // We didn't handle message, pass to DefWindowProc and record result
    Msg.Result := DefWindowProc( FProcessWindow, Msg.Msg, Msg.WParam,
      Msg.LParam );
end;

procedure TWorkerMgr.AfterConstruction;
begin
  inherited AfterConstruction;

  WaitForSingleObject( FReadyEvent, INFINITE );
  CloseHandle( FReadyEvent );

  if not FCreated then
    raise EWorkerMgr.Create( 'Can not create worker manager thread.' );

  FWorkerList := TThreadList< TWorker >.Create;
end;

procedure TWorkerMgr.BeforeDestruction;
begin
  if Assigned( FWorkerList ) then
  begin
    while FWorkerList.LockList.Count > 0 do
    begin
      FreeWorker( FWorkerList.LockList[ 0 ] );
      FWorkerList.LockList[ 0 ].Destroy;
      FWorkerList.Remove( FWorkerList.LockList[ 0 ] );
    end;

    FWorkerList.Free;
  end;

  inherited BeforeDestruction;
end;

constructor TWorkerMgr.Create( Name : string );
begin
  FName := name;
  FReadyEvent := CreateEvent( nil, True, FALSE, '' );
  inherited Create( FALSE );

  { Create hidden window here: store handle in FProcessWindow
    this must by synchonized because of ProcessThread Context }
  Synchronize( CreateProcessWindow );
end;

procedure TWorkerMgr.TerminatedSet;
begin
  // Exit Message Loop
  PostThreadMessage( WM_TERMINATE_WORKER_MGR, 0, 0 );
end;

procedure TWorkerMgr.DeleteProcessWindow;
begin
  if FProcessWindow <> 0 then
  begin
    DeallocateHWnd( FProcessWindow );
    FProcessWindow := 0;
  end;
end;

procedure TWorkerMgr.DeleteThreadWindow;
begin
  if FThreadWindow > 0 then
  begin
    DeallocateHWnd( FThreadWindow );
    FThreadWindow := 0;
  end;
end;

destructor TWorkerMgr.Destroy;
begin
  Terminate; // FTerminated := True;

  inherited Destroy; // WaitFor(), Destroy()

  { Destroy hidden window }
  DeleteProcessWindow( );
end;

procedure TWorkerMgr.Idle;
begin
end;

procedure TWorkerMgr.Execute;
var
  Msg : TMsg;
begin
  NameThreadForDebugging( FName );

  FException := nil;
  try
    // Force system alloc a Message Queue for thread
    // PeekMessage( Msg, 0, WM_USER, WM_USER, PM_NOREMOVE );

    CreateThreadWindow( );
    SetEvent( FReadyEvent );

    if FThreadWindow = 0 then
      raise EWorkerMgr.Create( 'Can not create worker manager window.' );

    FCreated := True;

    try
      while not Terminated do
      begin
        if FALSE then
        begin
          if Longint( PeekMessage( Msg, 0, 0, 0, PM_REMOVE ) ) > 0 then
          begin
            // WM_QUIT Message sent by Destroy()
            if Msg.message = WM_QUIT then
              Exit;

            TranslateMessage( Msg );
            DispatchMessage( Msg );
          end else begin
            Idle;
          end;
        end else begin
          while Longint( GetMessage( Msg, 0, 0, 0 ) ) > 0 do
          begin
            TranslateMessage( Msg );
            DispatchMessage( Msg );
          end;
          // WM_QUIT Message sent by Destroy()
        end;
      end;
    finally
      DeleteThreadWindow( );
    end;

  except
    HandleException;
  end;
end;

procedure TWorkerMgr.HandleException;
begin
  FException := Exception( ExceptObject );
  try
    if FException is EAbort then // Don't show EAbort messages
      Exit;

    // Now actually show the exception in Appliction Context
    Synchronize( HandleExceptionProcesshronized );
  finally
    FException := nil;
  end;
end;

function TWorkerMgr.PostThreadMessage( Msg, WParam, LParam : NativeUInt )
  : LongBool;
begin
  while FThreadWindow = 0 do
    SwitchToThread;

  Result := Winapi.Windows.PostMessage( FThreadWindow, Msg, WParam, LParam );
end;

function TWorkerMgr.SendThreadMessage( Msg, WParam, LParam : NativeUInt )
  : NativeInt;
begin
  while FThreadWindow = 0 do
    SwitchToThread;

  Result := Winapi.Windows.SendMessage( FThreadWindow, Msg, WParam, LParam );
end;

function TWorkerMgr.PostProcessMessage( Msg, WParam, LParam : NativeUInt )
  : LongBool;
begin
  Result := Winapi.Windows.PostMessage( FProcessWindow, Msg, WParam, LParam );
end;

function TWorkerMgr.SendProcessMessage( Msg, WParam, LParam : NativeUInt )
  : NativeInt;
begin
  Result := Winapi.Windows.SendMessage( FProcessWindow, Msg, WParam, LParam );
end;

procedure TWorkerMgr.ProcessWndMethod( var Msg : TMessage );
var
  Handled : Boolean;
  Worker : TWorker;
begin
  Handled := True; // Assume we handle message

  Worker := TWorker( Msg.WParam );

  case Msg.Msg of

    WM_WORKER_NEED_SUSPEND :
      begin
        Worker.DoNeedSuspend( PLongBool( Msg.LParam ) );
      end;

    WM_WORKER_NEED_CANCEL :
      begin
        Worker.DoNeedCancel( PLongBool( Msg.LParam ) );
      end;

    WM_WORKER_FEEDBACK_PROGRESS :
      begin
        Worker.DoProgress( Integer( Msg.LParam ) );
      end;

    WM_WORKER_FEEDBACK_DATA :
      begin
        Worker.DoData( PWorkerDataRec( Msg.LParam ) );
      end;

    WM_WORKER_FINISHED :
      begin
        Worker.DoDone( TWorkerStatus( Msg.LParam ) );
      end;

    WM_WORKER_SUSPENDED :
      begin
        Worker.DoSuspended( );
      end;

    WM_WORKER_RESUMED :
      begin
        Worker.DoResumed( );
      end;

    WM_WORKER_STARTED :
      begin
        Worker.DoStarted( );
      end;

  else
    Handled := FALSE; // We didn't handle message
  end;

  if Handled then // We handled message - record in message result
    Msg.Result := 0
  else // We didn't handle message, pass to DefWindowProc and record result
    Msg.Result := DefWindowProc( FProcessWindow, Msg.Msg, Msg.WParam,
      Msg.LParam );
end;

procedure TWorkerMgr.CreateProcessWindowEx;
begin
  FProcessWindow := AllocateHWnd( ProcessWndMethodEx );
end;

procedure TWorkerMgr.ProcessWndMethodEx( var Msg : TMessage );
begin
  Dispatch( Msg );
end;

procedure TWorkerMgr.ProcessWndMessageEx( var Msg : TMessage );
begin

end;

initialization

WorkerMgr := TWorkerMgr.Create( );

finalization

WorkerMgr.Free;

end.
