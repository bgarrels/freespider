unit ApacheAdapter;


{
*******************************************************************************************************************

  ApaacheApapter:  Decodes Apache Module reqeuest and response, triggers ApacheModule component
  Author:        Motaz Abdel Azeem
  Forked from:   http://wiki.freepascal.org/FPC_and_Apache_Modules
  email:         motaz@code.sd
  Home page:     http://code.sd
  License:       LGPL
  Last modified: 22.July.2012

*******************************************************************************************************************
}


{$mode objfpc}{$H+}

interface


uses
  Classes, SysUtils, httpd, apr, SpiderApache, SpiderUtils, SpiderCGI, syncobjs;

function ProcessHandler(r: Prequest_rec; WebModule: TDataModuleClass; ModuleName,
  HandlerName: string; ThreadPool: Boolean = True): Integer;

implementation

type

  { TMyWeb }

  TMyWeb = class
    public
      IsFinished: Boolean;
      Web: TDataModule;
      constructor Create;
      destructor Destroy; override;
  end;

var
  myWebPool: array of TMyWeb;
  MyCS: TCriticalSection;
  LastRequest: TDateTime;


(* GetDataModuleFromPool: Thread Pooling implementation *)

function GetDataModuleFromPool(WebModule: TDataModuleClass): TMyWeb;
var
  i: Integer;
  aWeb: TMyWeb;
  Found: Boolean;
  FirstEmpty: Integer;
  AllFinished: Boolean;

begin
  MyCS.Enter; // Enter critical section
  Found:= False;
  FirstEmpty:= -1;
  try
    // Remove all web modules in idle time to reduce memory leak
    AllFinished:= True;
    if (LastRequest + EncodeTime(0, 3, 0, 0) < Now) and (Length(myWebPool) > 0) then
    begin
      for i:= 0 to High(myWebPool) do
      if (Assigned(myWebPool[i])) and (myWebPool[i].IsFinished) then
      begin
        myWebPool[i].Web.Free;
        myWebPool[i].Free;
        myWebPool[i]:= nil;;
      end
      else
      if (AllFinished) and (Assigned(myWebPool[i])) then
        AllFinished:= False;
      if (Length(myWebPool) > 0) and AllFinished then
        SetLength(myWebPool, 0);
    end;

    LastRequest:= Now;


    // Search for reusable Web module

    for i:= 0 to High(myWebPool) do
    begin
      if (FirstEmpty = -1) and not Assigned(myWebPool[i]) then
        FirstEmpty:= i;

      if Assigned(myWebPool[i]) and (myWebPool[i].IsFinished) then
      begin
        Result:= myWebPool[i];
        Found:= True;
        Break;
      end;
    end;

    // No available web module, create new one, add it to the pool
    if not Found then
    begin
      Result:= TMyWeb.Create;
      Result.IsFinished:= False;
      Result.Web:= WebModule.Create(nil);
      if FirstEmpty = -1 then
      begin
        SetLength(myWebPool, Length(myWebPool) + 1);
        FirstEmpty:= High(myWebPool);
      end;
      myWebPool[FirstEmpty]:= Result;
    end;

  finally
    MyCS.Leave;
  end;
end;

function ProcessHandler(r: Prequest_rec; WebModule: TDataModuleClass; ModuleName,
  HandlerName: string; ThreadPool: Boolean = True): Integer;
var
  RequestedHandler: string;
  Buf: array [0 .. 20024] of Char;
  NumRead: Integer;
  Line: string;
  Head: Papr_array_header_t;
  Access: Phtaccess_result;
  aWeb: TMyWeb;
  i: Integer;
  SpiderApacheObj: TSpiderApache;
  aResponse: TSpiderResponse;
  ContentType: string;
  j: Integer;
  PostedData: string;
  Data: Pointer;
  DataLen: Integer;
  WebFound: Boolean;
  FoundIndex: Integer;
  CGICom: TSpiderCGI;
begin
  RequestedHandler := r^.handler;

  aWeb:= nil;
  { We decline to handle a request if configured handler is not the value of r^.handler }
  if not SameText(RequestedHandler, HANDLERNAME) then
  begin
    Result := DECLINED;
    Exit;
  end;

  { The following line just prints a message to the errorlog }
  // ap_log_error(PChar(MODULENAME), 54, APLOG_NOERRNO or APLOG_NOTICE,
  //  {$ifndef Apache1_3}0,{$endif} r^.server,
  //  'mod_hello: %s', [PChar('Before content is output')]);

  { We set the content type before doing anything else }

  ap_set_content_type(r, 'text/html');


  { If the request is for a header only, and not a request for
   the whole content, then return OK now. We don't have to do
   anything else. }
  if (r^.header_only <> 0) then
  begin
    Result := OK;
    Exit;
  end;

  try
    Line:= '';
    PostedData:= '';
    // read posted data
    if (r^.method = 'POST') then
    begin
      ap_setup_client_block(r, REQUEST_CHUNKED_DECHUNK);
      repeat
        NumRead:= ap_get_client_block(r, Buf, SizeOf(Buf));
        SetLength(Line, NumRead);
        Move(Buf, Pointer(Line)^, NumRead);
        PostedData:= PostedData + Line;
      until NumRead = 0;
    end;

    if ThreadPool then
      aWeb:= GetDataModuleFromPool(WebModule)
    else
    begin
      aWeb:= TMyWeb.Create;
      aweb.Web:= WebModule.Create(nil);
    end;

    // Search for SpiderApache component in Web Data Module
    with aWeb.web do
    for i:= 0 to ComponentCount - 1 do
    if Components[i] is TSpiderApache then
    begin
      aResponse:= nil;
      SpiderApacheObj:= Components[i] as TSpiderApache;
      ContentType:= apr_table_get(r^.headers_in, 'CONTENT-TYPE');
      if Trim(ContentType) = '' then
        ContentType:= r^.content_type;

      // Intialize SpiderApache:
      SpiderApacheObj.Init(r^.path_info, ContentType, r^.method, r^.args, apr_table_get(r^.headers_in, 'COOKIE'),
      apr_table_get(r^.headers_in, 'User-Agent'), Posteddata, apr_table_get(r^.headers_in, 'Content-Length'),
        apr_table_get(r^.headers_in, 'REFERER'), r^.connection^.remote_ip, r^.uri, ap_get_server_version);


      // Execute web application
      aResponse:= SpiderApacheObj.Execute;


      // Send response to the browser
      if Assigned(aResponse) then
      begin
        // Content type
        ap_set_content_type(r, PChar(aResponse.ContentType));

        // Custome header
        with aResponse.CustomHeader do
        for j:= 0 to Count - 1 do
          apr_table_set(r^.headers_out, PChar(Copy(Strings[j], 1, Pos(':', Strings[j]) - 1)),
            PChar(Copy(Strings[j], Pos(':', Strings[j]) + 1, Length(Strings[j])) ));

        // Response contents
        DataLen:= Length(aResponse.Content.Text);
        Data:= GetMem(DataLen);
        Move(Pointer(aResponse.Content.Text)^, Data^, DataLen);
        ap_rwrite(Data, DataLen, r);
      //  FreeMem(Data);


        // Set cookies:
        with aResponse.CookieList do
        for j:= 0 to Count - 1 do
          apr_table_set(r^.headers_out, 'Set-Cookie', PChar(Copy(Strings[j],
            Pos(':', Strings[j]) + 1, Length(Strings[j]))));

        aResponse.CookieList.Clear;
        aResponse.CustomHeader.Clear;
        aResponse.Content.Clear;

        apr_table_clear(r^.headers_in);

      end;

      Break;
    end;

  except
    on e: exception do
    ap_rputs(PChar('<br/> Error in WebModule : <font color=red>' + e.Message + '</font>'), r);
  end;

  if Assigned(aWeb) then
  if ThreadPool then
    aWeb.IsFinished:= True
  else
  begin
    aWeb.Web.Free;
    aWeb.Free;
  end;

  Result:= Ok;
end;

{ TMyWeb }

constructor TMyWeb.Create;
begin
  inherited Create;
  IsFinished:= False;
  Web:= nil;
end;

destructor TMyWeb.Destroy;
begin
  inherited Destroy;
end;

initialization

  MyCS:= TCriticalSection.Create;
end.

