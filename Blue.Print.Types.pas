﻿unit Blue.Print.Types;

interface

uses System.Rtti, System.Classes, System.SysUtils, {$IFDEF PAS2JS}Web{$ELSE}Web.HTTPApp, System.Net.Mime, System.NetEncoding{$ENDIF};

type
  TRequestMethod = (rmDelete, rmGet, rmPatch, rmPost, rmPut);
  TParamType = (ptBody, ptQuery, ptPath);

  TRequestFile = {$IFDEF PAS2JS}TJSHTMLFile{$ELSE}TAbstractWebRequestFile{$ENDIF};
  TResponseFile = {$IFDEF PAS2JS}TJSBlob{$ELSE}TStream{$ENDIF};
  TFormData = {$IFDEF PAS2JS}TJSFormData{$ELSE}TMultipartFormData{$ENDIF};

  EHTTPStatusError = class(Exception)
  private
    FStatusCode: Integer;
    FContent: String;
  public
    constructor Create(const StatusCode: Integer; const URL, Content: String);

    property Content: String read FContent;
    property StatusCode: Integer read FStatusCode;
  end;

  TRequestMethodAttribute = class(TCustomAttribute)
  private
    FMethod: TRequestMethod;

    constructor Create(const Method: TRequestMethod);
  public
    property Method: TRequestMethod read FMethod;
  end;

  DeleteAttribute = class(TRequestMethodAttribute)
  public
    constructor Create;
  end;

  GetAttribute = class(TRequestMethodAttribute)
  public
    constructor Create;
  end;

  PatchAttribute = class(TRequestMethodAttribute)
  public
    constructor Create;
  end;

  PostAttribute = class(TRequestMethodAttribute)
  public
    constructor Create;
  end;

  PutAttribute = class(TRequestMethodAttribute)
  public
    constructor Create;
  end;

  TParamAttribute = class(TCustomAttribute)
  private
    FParamType: TParamType;

    constructor Create(const ParamType: TParamType);
  public
    property ParamType: TParamType read FParamType;
  end;

  ParameterInBody = class(TParamAttribute)
  public
    constructor Create;
  end;

  ParameterInQuery = class(TParamAttribute)
  public
    constructor Create;
  end;

  ParameterInPath = class(TParamAttribute)
  public
    constructor Create;
  end;

  RemoteNameAttribute = class(TCustomAttribute)
  private
    FRemoteName: String;
  public
    constructor Create(const RemoteName: String);

    property RemoteName: String read FRemoteName write FRemoteName;
  end;

  TAuthentication = class(TCustomAttribute)
  private
    class function GetHeaderFromAttribute(const RttiType: TRttiObject; var AuthenticationName, AuthenticationValue: String): Boolean;
  private
    FName: String;

    constructor Create(const Name: String);
  public
    class function LoadHeaders(const Method: TRttiMethod; var AuthenticationName, AuthenticationValue: String): Boolean;

    function LoadHeaderValue: String; virtual;

    property Name: String read FName;
  end;

  BasicAuthenticationAttribute = class(TAuthentication)
  private
    FPassword: String;
    FUser: String;
  public
    constructor Create(const User, Password: String);

    function LoadHeaderValue: String; override;
  end;

  ContentTypeAttribute = class(TCustomAttribute)
  private
    FContentType: String;
    FCharSet: String;
  public
    constructor Create(const ContentType: String); overload;
    constructor Create(const ContentType, CharSet: String); overload;

    property CharSet: String read FCharSet;
    property ContentType: String read FContentType;
  end;

  AttachmentAttribute = class(ContentTypeAttribute)
  private
    FFileName: String;
  public
    constructor Create(const FileName, ContentType: String); reintroduce;

    property FileName: String read FFileName;
  end;

  HeaderAttribute = class(TCustomAttribute)
  private
    FName: String;
    FValue: String;
  public
    constructor Create(const Name, Value: String);

    property Name: String read FName;
    property Value: String read FValue;
  end;

function IsTypeKindString(const TypeKind: TTypeKind): Boolean;

implementation

function IsTypeKindString(const TypeKind: TTypeKind): Boolean;
begin
  Result := TypeKind in [{$IFDEF DCC}tkAnsiChar, tkAnsiString, tkLString, tkWString, tkUString, tkWChar, {$ENDIF}tkChar, tkString];
end;

function ConvertToBase64(const Value: String): String;
begin
  Result :=
    {$IFDEF PAS2JS}
    Window.btoa
    {$ELSE}
    TBase64Encoding.Base64.Encode
    {$ENDIF}
      (Value);
end;

{ EHTTPStatusError }

constructor EHTTPStatusError.Create(const StatusCode: Integer; const URL, Content: String);
begin
  inherited CreateFmt('HTTP Error %d for URL %s', [StatusCode, URL]);

  FContent := Content;
  FStatusCode := StatusCode;
end;

{ TRequestMethodAttribute }

constructor TRequestMethodAttribute.Create(const Method: TRequestMethod);
begin
  inherited Create;

  FMethod := Method;
end;

{ POSTAttribute }

constructor POSTAttribute.Create;
begin
  inherited Create(rmPost);
end;

{ GETAttribute }

constructor GETAttribute.Create;
begin
  inherited Create(rmGet);
end;

{ DELETEAttribute }

constructor DELETEAttribute.Create;
begin
  inherited Create(rmDelete);
end;

{ PATCHAttribute }

constructor PATCHAttribute.Create;
begin
  inherited Create(rmPatch);
end;

{ PUTAttribute }

constructor PUTAttribute.Create;
begin
  inherited Create(rmPut);
end;

{ TParamAttribute }

constructor TParamAttribute.Create(const ParamType: TParamType);
begin
  inherited Create;

  FParamType := ParamType;
end;

{ ParameterInBody }

constructor ParameterInBody.Create;
begin
  inherited Create(ptBody);
end;

{ ParameterInQuery }

constructor ParameterInQuery.Create;
begin
  inherited Create(ptQuery);
end;

{ ParameterInPath }

constructor ParameterInPath.Create;
begin
  inherited Create(ptPath);
end;

{ RemoteNameAttribute }

constructor RemoteNameAttribute.Create(const RemoteName: String);
begin
  inherited Create;

  FRemoteName := RemoteName;
end;

{ TAuthentication }

constructor TAuthentication.Create(const Name: String);
begin
  inherited Create;

  FName := Name;
end;

class function TAuthentication.GetHeaderFromAttribute(const RttiType: TRttiObject; var AuthenticationName, AuthenticationValue: String): Boolean;
var
  Attribute: TCustomAttribute;

begin
  AuthenticationValue := EmptyStr;
  Result := False;

  for Attribute in RttiType.GetAttributes do
    if Attribute is TAuthentication then
    begin
      AuthenticationName := TAuthentication(Attribute).Name;
      AuthenticationValue := TAuthentication(Attribute).LoadHeaderValue;

      Exit(True);
    end;
end;

class function TAuthentication.LoadHeaders(const Method: TRttiMethod; var AuthenticationName, AuthenticationValue: String): Boolean;
begin
  Result := GetHeaderFromAttribute(Method, AuthenticationName, AuthenticationValue) or GetHeaderFromAttribute(Method.Parent, AuthenticationName, AuthenticationValue);
end;

function TAuthentication.LoadHeaderValue: String;
begin
  Result := EmptyStr;
end;

{ BasicAuthenticationAttribute }

constructor BasicAuthenticationAttribute.Create(const User, Password: String);
begin
  inherited Create('Basic');

  FPassword := Password;
  FUser := User;
end;

function BasicAuthenticationAttribute.LoadHeaderValue: String;
begin
  Result := ConvertToBase64(Format('%s:%s', [FUser, FPassword]));
end;

{ ContentTypeAttribute }

constructor ContentTypeAttribute.Create(const ContentType: String);
begin
  inherited Create;

  FContentType := ContentType;
end;

constructor ContentTypeAttribute.Create(const ContentType, CharSet: String);
begin
  Create(ContentType);

  FCharSet := CharSet;
end;

{ AttachmentAttribute }

constructor AttachmentAttribute.Create(const FileName, ContentType: String);
begin
  inherited Create(ContentType);

  FFileName := FileName;
end;

{ HeaderAttribute }

constructor HeaderAttribute.Create(const Name, Value: String);
begin
  inherited Create;

  FName := Name;
  FValue := Value;
end;

end.

