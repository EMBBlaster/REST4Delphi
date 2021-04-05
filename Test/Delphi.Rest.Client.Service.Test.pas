unit Delphi.Rest.Client.Service.Test;

interface

uses DUnitX.TestFramework;

type
  [TestFixture]
  TClientServiceTest = class
  public
    [SetupFixture]
    procedure SetupFixture;
    [Test]
    procedure WhenCallTheProcedureMustGenerateTheRequestForServer;
    [Test]
    procedure TheURLOfServerCallMustContainTheNameOfInterfacePlusTheProcedureName;
    [Test]
    procedure WhenCallSendRequestMustSendABodyInParams;
    [Test]
    procedure TheURLPassedInConstructorMustContatWithTheRequestURL;
    [Test]
    procedure WhenCallAFunctionMustReturnTheValueOfFunctionAsSpected;
    [Test]
    procedure WhenCallAFunctionMustConvertTheFunctionParamsInTheGetURL;
    [Test]
    procedure SendingARequestWithoutParamsMustLoadTheURLWithoutParamSeparator;
    [Test]
    procedure SendingARequestWithOneParamMustPutTheParamSeparatorInTheURLAndTheNameAndValueParam;
    [Test]
    procedure WhenTheRequestHasMoreThenOneParameterMustSepareteThenWithTheSeparetorChar;
  end;

  IServiceTest = interface(IInvokable)
    ['{61DCD8A8-AD02-4EA3-AFC7-8425F7B12D6B}']
    function TestFunction: Integer;

    procedure TestProcedure;
    procedure TestProcedureWithOneParam(Param: String);
    procedure TestProcedureWithParam(Param1: String; Param2: Integer);
  end;

implementation

uses System.SysUtils, System.Rtti, Delphi.Rest.Client.Service, Delphi.Mock, Delphi.Rest.JSON.Serializer, Delphi.Rest.JSON.Serializer.Intf;

{ TClientServiceTest }

procedure TClientServiceTest.SendingARequestWithOneParamMustPutTheParamSeparatorInTheURLAndTheNameAndValueParam;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('/ServiceTest/TestProcedureWithOneParam?Param="abcd"'));

  Service.TestProcedureWithOneParam('abcd');

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.SendingARequestWithoutParamsMustLoadTheURLWithoutParamSeparator;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('/ServiceTest/TestProcedure'));

  Service.TestProcedure;

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.SetupFixture;
begin
  // Avoiding memory leak reporting.
  TMock.CreateInterface<IRestCommunication>;
  var Client := TClientService.Create(EmptyStr, nil, False);
  var Serializer: IRestJsonSerializer := TRestJsonSerializer.Create;
  var Service := Client.GetService<IServiceTest>;

  Serializer.Serialize('abc');
end;

procedure TClientServiceTest.TheURLOfServerCallMustContainTheNameOfInterfacePlusTheProcedureName;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('/ServiceTest/TestProcedure'));

  Service.TestProcedure;

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.TheURLPassedInConstructorMustContatWithTheRequestURL;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create('http://myurl.com', Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('http://myurl.com/ServiceTest/TestProcedure'));

  Service.TestProcedure;

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.WhenCallAFunctionMustConvertTheFunctionParamsInTheGetURL;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('/ServiceTest/TestProcedureWithParam?Param1="abc"&Param2=123'));

  Service.TestProcedureWithParam('abc', 123);

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.WhenCallAFunctionMustReturnTheValueOfFunctionAsSpected;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Setup.WillReturn('8888').When.SendRequestSync(It.IsAny<String>);

  Assert.AreEqual(8888, Service.TestFunction);

  Client.Free;
end;

procedure TClientServiceTest.WhenCallSendRequestMustSendABodyInParams;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsAny<String>);

  Service.TestProcedureWithParam('String', 1234);

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.WhenCallTheProcedureMustGenerateTheRequestForServer;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsAny<String>);

  Service.TestProcedure;

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

procedure TClientServiceTest.WhenTheRequestHasMoreThenOneParameterMustSepareteThenWithTheSeparetorChar;
begin
  var Communication := TMock.CreateInterface<IRestCommunication>;

  var Client := TClientService.Create(EmptyStr, Communication.Instance, False);
  var Service := Client.GetService<IServiceTest>;

  Communication.Expect.Once.When.SendRequestSync(It.IsEqualTo('/ServiceTest/TestProcedureWithParam?Param1="abcd"&Param2=1234'));

  Service.TestProcedureWithParam('abcd', 1234);

  Assert.AreEqual(EmptyStr, Communication.CheckExpectations);

  Client.Free;
end;

end.

