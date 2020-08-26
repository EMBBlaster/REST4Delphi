unit Delphi.Rest.Client.Service;

interface

uses System.Rtti, System.SysUtils, System.Types, Delphi.Rest.Communication;

type
  TClientService = class
  private
    FCommunication: IRestCommunication;
    FContext: TRttiContext;
    FRttiType: TRttiInterfaceType;
    FURL: String;

{$IFDEF PAS2JS}
    function OnInvokeMethod(const aMethodName: String; const Args: TJSValueDynArray): JSValue;
{$ELSE}
    procedure OnInvokeMethod(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
{$ENDIF}
  public
    constructor Create(URL: String; Communication: IRestCommunication);

    function GetService<T{$IFDEF DCC}: IInterface{$ENDIF}>: T;
  end;

implementation

{ TClientService }

constructor TClientService.Create(URL: String; Communication: IRestCommunication);
begin
  inherited Create;

  FCommunication := Communication;
  FContext := TRttiContext.Create;
  FURL := URL;
end;

function TClientService.GetService<T>: T;
var
  Instance: TVirtualInterface;

begin
  FRttiType := FContext.GetType(TypeInfo(T)) as TRttiInterfaceType;
  Instance := TVirtualInterface.Create(TypeInfo(T), {$IFDEF PAS2JS}@{$ENDIF}OnInvokeMethod);

  Instance.QueryInterface(FRttiType.GUID, Result);
end;

{$IFDEF PAS2JS}
function TClientService.OnInvokeMethod(const aMethodName: String; const Args: TJSValueDynArray): JSValue;
{$ELSE}
procedure TClientService.OnInvokeMethod(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
{$ENDIF}
var
{$IFDEF PAS2JS}
  Method: TRttiMethod;

{$ENDIF}
  A: Integer;

  Body: TBody;

begin
  Body := TBody.Create;
{$IFDEF PAS2JS}
  Method := FRttiType.GetMethod(aMethodName);
{$ENDIF}

  for A := Succ(Low(Args)) to High(Args) do
    Body.Values := Body.Values + [{$IFDEF PAS2JS}TValue.FromJSValue{$ENDIF}(Args[A])];

  FCommunication.SendRequest(Format('%s/%s/%s', [FURL, Method.Parent.Name.Substring(1), Method.Name]), Body);

  Body.Free;
end;

end.

