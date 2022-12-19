﻿unit Delphi.Rest.Remote.Service;

interface

uses System.Rtti, System.SysUtils, System.Types, System.TypInfo, System.Classes, {$IFDEF DCC}System.Net.HTTPClient, Rest.Types, {$ENDIF}Delphi.Rest.Types,
  Delphi.Rest.JSON.Serializer.Intf;

type
  TRestRequest = class
  public
    Body: TValue;
    FileDownload: Boolean;
    Headers: String;
    Method: TRESTRequestMethod;
    URL: String;
  end;

  IRestCommunication = interface
    ['{33BB3249-F044-4BDF-B3E0-EA2378A040C4}']
    function SendRequest(const Request: TRestRequest): String;
    {$IFDEF PAS2JS}
    function SendRequestAsync(const Request: TRestRequest): String; async;
    {$ENDIF}
  end;

  TRestCommunication = class(TInterfacedObject, IRestCommunication)
  private
    {$IFDEF DCC}
    FConnection: THTTPClient;
    {$ENDIF}
    FHeaders: TStringList;

    {$IFDEF DCC}
    function GetConnection: THTTPClient;
    {$ENDIF}
    function SendRequest(const Request: TRestRequest): String;
    {$IFDEF PAS2JS}
    function SendRequestAsync(const Request: TRestRequest): String; async;
    {$ENDIF}

    {$IFDEF DCC}
    property Connection: THTTPClient read GetConnection;
    {$ENDIF}
  public
    constructor Create;

    destructor Destroy; override;
  end;

  TRemoteService = class(TVirtualInterface)
  private
    FCommunication: IRestCommunication;
    FContext: TRttiContext;
    FFormData: TRESTFormData;
    FHeaders: TStringList;
    FOnExecuteException: TProc<Exception, IRestJsonSerializer>;
    FRequest: TRestRequest;
    FRttiType: TRttiInterfaceType;
    FSerializer: IRestJsonSerializer;
    FURL: String;

    function CheckForceFormData(const Method: TRttiMethod): Boolean;
    function CheckParameterIsFile(const Parameter: TRttiParameter): Boolean;
    function CheckMethodParameterHasFile(const Method: TRttiMethod): Boolean;
    function Deserialize(const JSON: String; RttiType: TRttiType): TValue;
    function EncodeParamValue(const ParamValue: TValue): String;
    function GetCommandFromMethod(const Method: TRttiMethod): TRESTRequestMethod;
    function GetFormData: TRESTFormData;
    function GetHeader(const Index: String): String;
    function GetHeaders: String;
    function GetParameterType(const Parameter: TRttiParameter): TRESTParamType;
    function GetRemoteNameAttribute(const RttiType: TRttiNamedObject; var Name: String): Boolean;
    function GetRemoteRequestName(const RttiType: TRttiNamedObject): String;
    function GetRemoteRequestServiceName: String;
    function HasAttachment(const Method: TRttiMethod): Boolean;

    procedure AddFormDataField(const Param: TRttiParameter; const ParamValue: String);
    procedure AddFormDataFile(const Param: TRttiParameter; const AFile: TRESTRequestFile);
    procedure AddParamToTheBody(const Param: TRttiParameter; const ParamValue: TValue; const ForceLoadFormData: Boolean);
    procedure CheckException(const Error: Exception);
    procedure LoadRequest(const Method: TRttiMethod; const Args: TArray<TValue>);
    procedure LoadRequestAuthentication(const Method: TRttiMethod);
    procedure LoadRequestHeaders;
    procedure LoadRequestParams(const Method: TRttiMethod; const Args: TArray<TValue>);
    procedure LoadRequestURL(const Method: TRttiMethod; const Args: TArray<TValue>);
    procedure OnInvokeMethod(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);
    procedure SetHeader(const Index, Value: String);
    procedure SetHeaders(const Value: String);

    property FormData: TRESTFormData read GetFormData;
  public
    constructor Create(const TypeInfo: PTypeInfo);

    destructor Destroy; override;

    property Communication: IRestCommunication read FCommunication write FCommunication;
    property Header[const Index: String]: String read GetHeader write SetHeader;
    property Headers: String read GetHeaders write SetHeaders;
    property OnExecuteException: TProc<Exception, IRestJsonSerializer> read FOnExecuteException write FOnExecuteException;
    property RttiType: TRttiInterfaceType read FRttiType;
    property Serializer: IRestJsonSerializer read FSerializer write FSerializer;
    property URL: String read FURL write FURL;
  end;

  IRemoteServiceFactory = interface
    function GetService(const &Type: PTypeInfo; const URL: String): TRemoteService;
  end;

  TRemoteServiceFactory = class(TInterfacedObject, IRemoteServiceFactory)
  private
    class var GRemoteServiceFactory: IRemoteServiceFactory;
  private
    FCommunication: IRestCommunication;
    FHeaders: String;
    FOnExecuteException: TProc<Exception, IRestJsonSerializer>;
    FSerializerFactory: TFunc<IRestJsonSerializer>;
    FURL: String;

    class function GetRemoteServiceFactory: TRemoteServiceFactory; static;

    function GetCommunication: IRestCommunication;
    function GetService(const &Type: PTypeInfo; const URL: String): TRemoteService; overload;
  public
    class constructor Create;

    class function GetService<I: IInterface>(const URL: String): I; overload;

    property Communication: IRestCommunication read GetCommunication write FCommunication;
    property Headers: String read FHeaders write FHeaders;
    property OnExecuteException: TProc<Exception, IRestJsonSerializer> read FOnExecuteException write FOnExecuteException;
    property SerializerFactory: TFunc<IRestJsonSerializer> read FSerializerFactory write FSerializerFactory;
    property URL: String read FURL write FURL;

    class property Instance: TRemoteServiceFactory read GetRemoteServiceFactory;
  end;

implementation

uses Delphi.Rest.Exceptions,
{$IFDEF PAS2JS}
  JS, Web, WebOrWorker, Pas2Js.Rest.JSON.Serializers
{$ELSE}
  System.Net.Mime, System.NetConsts, System.Net.URLClient, Delphi.Rest.JSON.Serializer, Web.HTTPApp
{$ENDIF};

const
  COMPILER_OFFSET = {$IFDEF PAS2JS}0{$ELSE}1{$ENDIF};

{$IFDEF PAS2JS}
procedure DownloadFile(const URL: String); async;
var
  Anchor: TJSHTMLAnchorElement;

begin
  Anchor := Document.CreateElement('a') as TJSHTMLAnchorElement;
  Anchor.HRef := URL;
  Anchor.Style.cssText := 'display:none';

  Document.Body.AppendChild(Anchor);

  Anchor.Click();

  Document.Body.RemoveChild(Anchor);
end;
{$ENDIF}

{ TRemoteService }

procedure TRemoteService.AddFormDataField(const Param: TRttiParameter; const ParamValue: String);
begin
{$IFDEF PAS2JS}
  FormData.Append(Param.Name, ParamValue);
{$ELSE}
  FormData.AddField(Param.Name, ParamValue);
{$ENDIF}
end;

procedure TRemoteService.AddFormDataFile(const Param: TRttiParameter; const AFile: TRESTRequestFile);
begin
{$IFDEF PAS2JS}
  FormData.Append(Param.Name, AFile);
{$ELSE}
  if Assigned(AFile) then
    FormData.AddStream(Param.Name, AFile.Stream, AFile.FileName);
{$ENDIF}
end;

procedure TRemoteService.AddParamToTheBody(const Param: TRttiParameter; const ParamValue: TValue; const ForceLoadFormData: Boolean);
var
  AFile: TRESTRequestFile;

begin
  if ParamValue.IsType<TRESTRequestFile>(False) then
    if ForceLoadFormData then
      AddFormDataFile(Param, ParamValue.AsType<TRESTRequestFile>)
    else
      FRequest.Body := ParamValue
  else if (Param.ParamType is TRttiDynamicArrayType) and (TRttiDynamicArrayType(Param.ParamType).ElementType.Handle = TypeInfo(TRESTRequestFile)) then
    for AFile in ParamValue.AsType<TArray<TRESTRequestFile>> do
      AddFormDataFile(Param, AFile)
  else if ForceLoadFormData then
    AddFormDataField(Param, EncodeParamValue(ParamValue))
  else
    FRequest.Body := TValue.From(EncodeParamValue(ParamValue));
end;

procedure TRemoteService.CheckException(const Error: Exception);
begin
  if Assigned(FOnExecuteException) then
    OnExecuteException(Error, Serializer)
  else
    raise {$IFDEF PAS2JS}Error{$ELSE}AcquireExceptionObject as Exception{$ENDIF};
end;

function TRemoteService.CheckForceFormData(const Method: TRttiMethod): Boolean;
var
  Parameter: TRttiParameter;

  BodyParamCount: Integer;

begin
  BodyParamCount := 0;

  for Parameter in Method.GetParameters do
    if GetParameterType(Parameter) = ptBody then
      Inc(BodyParamCount);

  Result := BodyParamCount > 1;
end;

function TRemoteService.CheckMethodParameterHasFile(const Method: TRttiMethod): Boolean;
var
  Param: TRttiParameter;

begin
  Result := False;

  for Param in Method.GetParameters do
    if CheckParameterIsFile(Param) then
      Exit(True);
end;

function TRemoteService.CheckParameterIsFile(const Parameter: TRttiParameter): Boolean;
begin
  Result := (Parameter.ParamType.Handle = TypeInfo(TRESTRequestFile)) or (Parameter.ParamType.Handle = TypeInfo(TArray<TRESTRequestFile>));
end;

constructor TRemoteService.Create(const TypeInfo: PTypeInfo);
begin
  inherited Create(TypeInfo, {$IFDEF PAS2JS}@{$ENDIF}OnInvokeMethod);

  FContext := TRttiContext.Create;
  FHeaders := TStringList.Create;
  FRttiType := FContext.GetType(TypeInfo) as TRttiInterfaceType;
end;

function TRemoteService.Deserialize(const JSON: String; RttiType: TRttiType): TValue;
begin
  if Assigned(RttiType) then
    Result := Serializer.Deserialize(JSON, RttiType.Handle)
  else
    Result := TValue.Empty;
end;

destructor TRemoteService.Destroy;
begin
  FRequest.Free;

  FHeaders.Free;

{$IFDEF DCC}
  FFormData.Free;
{$ENDIF}

  inherited;
end;

function TRemoteService.EncodeParamValue(const ParamValue: TValue): String;
begin
  if IsTypeKindString(ParamValue.Kind) then
    Result := ParamValue.AsString
  else
    Result := Serializer.Serialize(ParamValue);
end;

function TRemoteService.GetCommandFromMethod(const Method: TRttiMethod): TRESTRequestMethod;

  procedure GetTypeFromAttribute(const RttiType: TRttiObject);
  var
    Attribute: TCustomAttribute;

  begin
    for Attribute in RttiType.GetAttributes do
      if Attribute is TRESTRequestMethodAttribute then
        Result := TRESTRequestMethodAttribute(Attribute).Method;
  end;

begin
  Result := rmGet;

  GetTypeFromAttribute(Method.Parent);

  GetTypeFromAttribute(Method);
end;

function TRemoteService.GetFormData: TRESTFormData;
begin
  if not Assigned(FFormData) then
    FFormData := TRESTFormData.{$IFDEF PAS2JS}new{$ELSE}Create{$ENDIF};

  Result := FFormData;
end;

function TRemoteService.GetHeader(const Index: String): String;
begin
  Result := FHeaders.Values[Index];
end;

function TRemoteService.GetHeaders: String;
begin
  Result := FHeaders.Text;
end;

function TRemoteService.GetParameterType(const Parameter: TRttiParameter): TRESTParamType;

  procedure GetTypeFromAttribute(const RttiType: TRttiObject);
  var
    Attribute: TCustomAttribute;

  begin
    for Attribute in RttiType.GetAttributes do
      if Attribute is TRESTParamAttribute then
        Result := TRESTParamAttribute(Attribute).ParamType;
  end;

begin
  if FRequest.Method in [rmPatch, rmPost, rmPut] then
    Result := ptBody
  else
    Result := ptQuery;

  GetTypeFromAttribute(Parameter.Parent);

  GetTypeFromAttribute(Parameter);

  if CheckParameterIsFile(Parameter) then
    Result := ptBody;
end;

function TRemoteService.GetRemoteNameAttribute(const RttiType: TRttiNamedObject; var Name: String): Boolean;
var
  CustomAttribute: TCustomAttribute;

begin
  Name := EmptyStr;

  for CustomAttribute in RttiType.GetAttributes do
    if CustomAttribute is RemoteNameAttribute then
      Name := RemoteNameAttribute(CustomAttribute).RemoteName;

  Result := not Name.IsEmpty;

  if not Result then
    Name := RttiType.Name;
end;

function TRemoteService.GetRemoteRequestName(const RttiType: TRttiNamedObject): String;
begin
  GetRemoteNameAttribute(RttiType, Result);
end;

function TRemoteService.GetRemoteRequestServiceName: String;
begin
  if not GetRemoteNameAttribute(RttiType, Result) then
    Result := Result.Substring(1);
end;

function TRemoteService.HasAttachment(const Method: TRttiMethod): Boolean;
{$IFDEF PAS2JS}
var
  CustomAttribute: TCustomAttribute;

{$ENDIF}
begin
{$IFDEF PAS2JS}
  for CustomAttribute in Method.GetAttributes do
    if CustomAttribute is AttachmentAttribute then
      Exit(True);
{$ELSE}
  Result := Method.HasAttribute<AttachmentAttribute>;
{$ENDIF}
end;

procedure TRemoteService.LoadRequest(const Method: TRttiMethod; const Args: TArray<TValue>);
begin
  FRequest.Free;

{$IFDEF PAS2JS}
  FFormData := nil;
{$ELSE}
  FreeAndNil(FFormData);
{$ENDIF}

  FRequest := TRestRequest.Create;
  FRequest.FileDownload := HasAttachment(Method);
  FRequest.Method := GetCommandFromMethod(Method);

  LoadRequestAuthentication(Method);

  LoadRequestURL(Method, Args);

  LoadRequestHeaders;

  if CheckMethodParameterHasFile(Method) then
    FRequest.Method := rmPost;
end;

procedure TRemoteService.LoadRequestAuthentication(const Method: TRttiMethod);
var
  AuthenticationHeader, AuthenticationName: String;

begin
  AuthenticationHeader := EmptyStr;

  if TAuthentication.LoadHeaders(Method, AuthenticationName, AuthenticationHeader) then
    Header['Authorization'] := Format('%s %s', [AuthenticationName, AuthenticationHeader]);
end;

procedure TRemoteService.LoadRequestHeaders;
begin
  FRequest.Headers := Headers;
end;

procedure TRemoteService.LoadRequestParams(const Method: TRttiMethod; const Args: TArray<TValue>);
var
  A: Integer;

  Params: TArray<TRttiParameter>;

  ParamType: TRESTParamType;

  ParamValue: TValue;

  ForceFormData: Boolean;

  PathValues, QueryValues: TStringList;

begin
  ForceFormData := CheckForceFormData(Method);
  Params := Method.GetParameters;
  PathValues := TStringList.Create;
  PathValues.Delimiter := '/';
  PathValues.QuoteChar := #0;
  QueryValues := TStringList.Create;
  QueryValues.Delimiter := '&';
  QueryValues.QuoteChar := #0;

  for A := Low(Params) to High(Params) do
  begin
    ParamType := GetParameterType(Params[A]);
    ParamValue := Args[COMPILER_OFFSET + A];

    if ParamType = ptBody then
      AddParamToTheBody(Params[A], ParamValue, ForceFormData)
    else if ParamType = ptQuery then
      QueryValues.AddPair(Params[A].Name, EncodeParamValue(ParamValue))
    else
      PathValues.Add(ParamValue.ToString);
  end;

  if Assigned(FFormData) then
    FRequest.Body := TValue.From(FormData);

  if PathValues.Count > 0 then
    FRequest.URL := '/' + PathValues.DelimitedText;

  if QueryValues.Count > 0 then
    FRequest.URL := FRequest.URL + '?' + QueryValues.DelimitedText;

  PathValues.Free;

  QueryValues.Free;
end;

procedure TRemoteService.LoadRequestURL(const Method: TRttiMethod; const Args: TArray<TValue>);
begin
  LoadRequestParams(Method, Args);

  FRequest.URL := Format('%s/%s/%s%s', [FURL, GetRemoteRequestServiceName, GetRemoteRequestName(Method), FRequest.URL]);
end;

procedure TRemoteService.OnInvokeMethod(Method: TRttiMethod; const Args: TArray<TValue>; out Result: TValue);

  function SendRequest: String;
  begin
    Result := Communication.SendRequest(FRequest);
  end;
{$IFDEF PAS2JS}

  function InvokeMehodAsync: JSValue; async;
  var
    ReturnType: TRttiType;

  begin
    try
      ReturnType := Method.ReturnType;

      if Assigned(ReturnType) and ReturnType.IsInstanceExternal and (ReturnType.AsInstanceExternal.ExternalName = 'Promise') then
        ReturnType := nil;

      Result := Deserialize(await(Communication.SendRequestAsync(FRequest)), ReturnType).AsJSValue;
    except
      on E: Exception do
        CheckException(E);
    end;
  end;
{$ENDIF}

begin
  try
    LoadRequest(Method, Args);

    if FRequest.FileDownload then
    begin
      Result := TValue.Empty;

      SendRequest;
    end
    else
{$IFDEF PAS2JS}
    if Method.IsAsyncCall then
      Result := TValue.From(InvokeMehodAsync)
    else
{$ENDIF}
      Result := Deserialize(SendRequest, Method.ReturnType);
  except
    on E: Exception do
      CheckException(E);
  end;
end;

procedure TRemoteService.SetHeader(const Index, Value: String);
begin
  FHeaders.Values[Index] := Value;
end;

procedure TRemoteService.SetHeaders(const Value: String);
begin
  FHeaders.Text := Value;
end;

{ TRestCommunication }

constructor TRestCommunication.Create;
begin
  inherited;

  FHeaders := TStringList.Create;
end;

destructor TRestCommunication.Destroy;
begin
  FHeaders.Free;

{$IFDEF DCC}
  FConnection.Free;
{$ENDIF}

  inherited;
end;

{$IFDEF DCC}
function TRestCommunication.GetConnection: THTTPClient;
begin
  if not Assigned(FConnection) then
    FConnection := THTTPClient.Create;

  Result := FConnection;
end;
{$ENDIF}

function TRestCommunication.SendRequest(const Request: TRestRequest): String;
{$IFDEF PAS2JS}
var
  A: Integer;

  Connection: TJSXMLHttpRequest;

{$ELSE}
  function LoadContentStream: TStream;
  begin
    Result := nil;

    if not Request.Body.IsEmpty then
      if Request.Body.IsType<String> then
        Result := TStringStream.Create(Request.Body.AsString, TEncoding.UTF8)
      else if Request.Body.IsType<TMultipartFormData> then
      begin
        var Content := Request.Body.AsType<TMultipartFormData>;

        Connection.CustomHeaders[sContentType] := Content.MimeTypeHeader;
        Result := Content.Stream;
      end
      else if Request.Body.IsType<TAbstractWebRequestFile> then
        Result := TFileStream.Create(Request.Body.AsType<TAbstractWebRequestFile>.FileName, fmOpenRead or fmShareDenyWrite);
  end;

{$ENDIF}
begin
  FHeaders.Text := Request.Headers;

{$IFDEF PAS2JS}
  if Request.FileDownload then
    DownloadFile(Request.URL)
  else
  begin
    Connection := TJSXMLHttpRequest.New;

    Connection.Open(RESTRequestMethodToString(Request.Method), Request.URL, False);

    for A := 0 to Pred(FHeaders.Count) do
      Connection.setRequestHeader(FHeaders.Names[A], FHeaders.ValueFromIndex[A]);

    Connection.Send(Request.Body.AsJSValue);

    if Connection.Status = 200 then
      Result := Connection.ResponseText
    else
      raise EHTTPStatusError.Create(Connection.status, Request.URL, Connection.ResponseText);
  end;
{$ELSE}
  var Content: TStream := nil;

  try
    Content := LoadContentStream;
    Connection.ContentType := CONTENTTYPE_APPLICATION_JSON;
    Connection.ResponseTimeout := -1;
    Connection.SendTimeout := -1;

    for var A := 0 to Pred(FHeaders.Count) do
      Connection.CustomHeaders[FHeaders.Names[A]] := FHeaders.ValueFromIndex[A];

    var Response := Connection.Execute(RESTRequestMethodToString(Request.Method), Request.URL, Content) as IHTTPResponse;

    if Response.StatusCode <> 200 then
      raise EHTTPStatusError.Create(Response.StatusCode, Request.URL, Result);

    Result := Response.ContentAsString(TEncoding.UTF8);
  finally
    Content.Free;
  end;
{$ENDIF}
end;

{$IFDEF PAS2JS}
function TRestCommunication.SendRequestAsync(const Request: TRestRequest): String;
var
  A: Integer;

  Options: TJSFetchInit;

  Response: TJSResponse;

begin
  if Request.FileDownload then
    await(DownloadFile(Request.URL))
  else
  begin
    FHeaders.Text := Request.Headers;
    Options := TJSFetchInit.New;
    Options.Method := RESTRequestMethodToString(Request.Method);

    if FHeaders.Count > 0 then
    begin
      Options.Headers := TJSHTMLHeaders.New;

      for A := 0 to Pred(FHeaders.Count) do
        Options.Headers.Append(FHeaders.Names[A], FHeaders.ValueFromIndex[A]);
    end;

    if not Request.Body.IsEmpty then
      Options.Body := Request.Body.AsJSValue;

    Response := await(Window.Fetch(Request.URL, Options));

    Result := await(Response.Text);

    if Response.Status <> 200 then
      raise EHTTPStatusError.Create(Response.Status, Request.URL, Result);
  end;
end;
{$ENDIF}

{ TRemoteServiceFactory }

class constructor TRemoteServiceFactory.Create;
begin
  GRemoteServiceFactory := TRemoteServiceFactory.Create;
  TRemoteServiceFactory.Instance.SerializerFactory :=
    function: IRestJsonSerializer
    begin
      Result := TRestJsonSerializer.Create;
    end;
end;

function TRemoteServiceFactory.GetCommunication: IRestCommunication;
begin
  if not Assigned(FCommunication) then
    FCommunication := TRestCommunication.Create;

  Result := FCommunication;
end;

class function TRemoteServiceFactory.GetRemoteServiceFactory: TRemoteServiceFactory;
begin
  Result := TRemoteServiceFactory(GRemoteServiceFactory);
end;

function TRemoteServiceFactory.GetService(const &Type: PTypeInfo; const URL: String): TRemoteService;
begin
  Result := TRemoteService.Create(&Type);
  Result.Communication := Communication;
  Result.Headers := Headers;
  Result.OnExecuteException := OnExecuteException;
  Result.Serializer := FSerializerFactory();
  Result.URL := URL;
end;

class function TRemoteServiceFactory.GetService<I>(const URL: String): I;
var
  Service: TRemoteService;

begin
  Service := GRemoteServiceFactory.GetService(TypeInfo(I), URL);

  Service.QueryInterface(Service.RttiType.GUID, Result);
end;

end.

