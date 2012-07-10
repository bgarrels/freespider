unit FreeSpiderIDEIntf;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FormEditingIntf, ProjectIntf, NewItemIntf, LazIDEIntf,
  Controls, Forms, SpiderCGI;

Type

  { TFreeSpiderModuleDescriptor }

  TFreeSpiderModuleDescriptor = Class(TFileDescPascalUnitWithResource)
  Public
    Constructor Create; override;
    Function GetLocalizedName : String; override;
    Function GetLocalizedDescription : String; override;
    Function GetInterfaceUsesSection : String; override;
    function GetImplementationSource(const Filename, SourceName, ResourceName: string): string; override;
  end;

  { TFreeSpiderFileDescriptor }

  TFreeSpiderFileDescriptor = Class(TFileDescPascalUnitWithResource)
  Public
    Constructor Create; override;
    Function GetLocalizedName : String; override;
    Function GetLocalizedDescription : String; override;
    Function GetInterfaceUsesSection : String; override;
    function GetImplementationSource(const Filename, SourceName, ResourceName: string): string; override;
  end;

  { TFreeSpiderProjectDescriptor }

  TFreeSpiderProjectDescriptor = class(TProjectDescriptor)
  public
    constructor create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function InitProject(AProject: TLazProject) : TModalResult; override;
    function CreateStartFiles(AProject: TLazProject) : TModalResult; override;
  published
    { Published declarations }
  end;

  { TFreeSpiderApacheProjectDescriptor }

  TFreeSpiderApacheProjectDescriptor = class(TProjectDescriptor)
  public
    constructor create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function InitProject(AProject: TLazProject) : TModalResult; override;
    function CreateStartFiles(AProject: TLazProject) : TModalResult; override;
  published
    { Published declarations }
  end;

  { TFreeSpiderApacheSecondaryDescriptor }



Procedure Register;

implementation

uses FreeSpider;

Resourcestring
  SSpiderApps     = 'FreeSpider Web Application';
  SSpiderAppName  = 'FreeSpider CGI Web Application';
  SSpiderAppDescr = 'FreeSpider Web application, which is similar to WebBroker in Delphi.';
 // SSpiderName     = 'FreeSpider Data Module';
  //SSpiderDescr    = 'Data Module contains SpiderCGI, and other components';
  SSpiderModuleName  = 'Data Module';
  SSpiderModuleDescr = 'Data Module contains SpiderCGI, and other components';

  ASpiderApps = 'FreeSpider Apache Module web application';
  ASpiderAppName = 'FreeSpider Apache moule application';
  ASpiderAppDescr = 'FreeSpider apache module library';



Procedure Register;

begin
  RegisterNewItemCategory(TNewIDEItemCategory.Create(SSpiderApps));
  RegisterProjectDescriptor(TFreeSpiderProjectDescriptor.Create, SSpiderApps);
  //RegisterProjectFileDescriptor(TFreeSpiderFileDescriptor.Create,SSpiderApps);
  RegisterProjectFileDescriptor(TFreeSpiderModuleDescriptor.Create, SSpiderApps);
 // FormEditingHook.RegisterDesignerBaseClass(TSpiderMapper);
//  FormEditingHook.RegisterDesignerBaseClass(TSpider);

  // Apache module
  RegisterNewItemCategory(TNewIDEItemCategory.Create(ASpiderApps));
  RegisterProjectDescriptor(TFreeSpiderApacheProjectDescriptor.Create, ASpiderApps);
  RegisterProjectFileDescriptor(TFreeSpiderModuleDescriptor.Create, ASpiderApps);
end;


{ TFreeSpiderApacheProjectDescriptor }

constructor TFreeSpiderApacheProjectDescriptor.create;
begin
  inherited create;
  Flags:= Flags - [pfMainUnitHasCreateFormStatements];
  Name:= 'Spider Apache Module Application';
end;

function TFreeSpiderApacheProjectDescriptor.GetLocalizedName: string;
begin
  //Result:= inherited GetLocalizedName;
  Result:= ASpiderAppName;
end;

function TFreeSpiderApacheProjectDescriptor.GetLocalizedDescription: string;
begin
  //Result:= inherited GetLocalizedDescription;
  Result:= ASpiderAppDescr;
end;

function TFreeSpiderApacheProjectDescriptor.InitProject(AProject: TLazProject): TModalResult;
Var
  F : TLazProjectFile;
  Src : TStrings;
begin
  Result:= Inherited InitProject(AProject);
  If (Result=mrOK) then
    begin
    AProject.AddPackageDependency('FreeSpider');
    AProject.Title:= 'Spider Apache Module';
    AProject.LazCompilerOptions.Win32GraphicApp:= False;
    AProject.ProjectInfoFile:= 'apachemod1.lpi';
    F:= AProject.CreateProjectFile('apachemod1.lpr');
    F.IsPartOfProject:= True;
    AProject.AddFile(F, False);
    AProject.MainFileID:= 0;
    Src:= TStringList.Create;
    try
      With Src do
        begin
        Add('library ApacheMod1;');
        Add('');
        Add('Uses');
        Add('{$IFDEF UNIX}{$IFDEF UseCThreads}');
        Add('  CThreads,');
        Add('{$ENDIF}{$ENDIF}');
        Add('uses SysUtils, httpd, ApacheAdapter, apr, Web, Classes, SpiderApache, SpiderUtils;');
        Add('');
        Add('const');
        Add('          MODULE_NAME = ''mod_proj1.so'';');
        Add('          MODNAME = ''apache_mod1'';');
        Add('          HANDLER_NAME = ''freespider-handler'';');
        Add('');

        Add('begin');
        Add('-- some code');
        Add('  DataModule1:= TDataModule1.Create(nil)');
        Add('end.');
        end;
      F.SetSourceText(Src.Text);
    finally
      Src.Free;
    end;
   end;
end;

function TFreeSpiderApacheProjectDescriptor.CreateStartFiles(
  AProject: TLazProject): TModalResult;
Var
  FD : TProjectFileDescriptor;
  O : TNewFlags;
begin
  FD:= ProjectFileDescriptors.FindByName('DataModule1');
  O:= [nfIsPartOfProject, nfOpenInEditor, nfCreateDefaultSrc];
  Result:= LazarusIDE.DoNewEditorFile(FD, 'main.pas', '', O);
end;


{ TFreeSpiderFileDescriptor }

constructor TFreeSpiderFileDescriptor.Create;
begin
  inherited Create;
  ResourceClass:= TDataModule;
  Name:= 'Data Module';
  UseCreateFormStatements:= False;
end;

function TFreeSpiderFileDescriptor.GetLocalizedName: String;
begin
  Result:=SSpiderAppName;
end;

function TFreeSpiderFileDescriptor.GetLocalizedDescription: String;
begin
  Result:= SSpiderAppDescr;
end;

function TFreeSpiderFileDescriptor.GetInterfaceUsesSection: String;
begin
  Result:= inherited GetInterfaceUsesSection + '';
end;

function TFreeSpiderFileDescriptor.GetImplementationSource(const Filename,
  SourceName, ResourceName: string): string;
Var
  Src : TStrings;
begin
  Src:=TStringList.Create;
  try
    Result:= inherited GetImplementationSource(Filename, SourceName, ResourceName);
    With Src do
    begin
      Add('Procedure RegisterSpider;');
      Add('begin');
      Add('  RegisterSpiderClass(T'+ ResourceName + ')');
      Add('end;');
      Add('');
      Add(Result);
      Add('  RegisterSpider;');
      Result:=Text;
    end;
  finally
    Src.Free;
  end;
end;

{ TFreeSpiderProjectDescriptor }

constructor TFreeSpiderProjectDescriptor.create;

begin
  Inherited;
  Flags:= Flags - [pfMainUnitHasCreateFormStatements];
  Name:= 'Spider Application';
end;


function TFreeSpiderProjectDescriptor.GetLocalizedName: string;
begin
  Result:= SSpiderAppName;
end;

function TFreeSpiderProjectDescriptor.GetLocalizedDescription: string;
begin
  Result:= SSpiderAppDescr;
end;

function TFreeSpiderProjectDescriptor.InitProject(AProject: TLazProject): TModalResult;
Var
  F : TLazProjectFile;
  Src : TStrings;

begin
  Result:= Inherited InitProject(AProject);
  If (Result=mrOK) then
    begin
{    AProject.AddPackageDependency('FCL');
    AProject.AddPackageDependency('LCL');}
    AProject.AddPackageDependency('FreeSpider');
    AProject.Title:= 'Spider application';
    AProject.LazCompilerOptions.Win32GraphicApp:=False;
    AProject.ProjectInfoFile:= 'project1.lpi';
    F:= AProject.CreateProjectFile('project1.lpr');
    F.IsPartOfProject:= True;
   // AProject.LazCompilerOptions.LCLWidgetType:= 'NoGui';
    AProject.AddFile(F,False);
    AProject.MainFileID:= 0;
    Src:= TStringList.Create;
    try
      With Src do
        begin
        Add('Program SpiderProj1;');
        Add('');
        Add('Uses');
        Add('{$IFDEF UNIX}{$IFDEF UseCThreads}');
        Add('  CThreads,');
        Add('{$ENDIF}{$ENDIF}');
        Add('main');
        Add('  { add your units here };');
        Add('');
        Add('begin');
        Add('  DataModule1:= TDataModule1.Create(nil)');
        Add('end.');
        end;
      F.SetSourceText(Src.Text);
    finally
      Src.Free;
    end;
    end;
end;

function TFreeSpiderProjectDescriptor.CreateStartFiles(AProject: TLazProject): TModalResult;
Var
  FD : TProjectFileDescriptor;
  O : TNewFlags;
begin
  FD:= ProjectFileDescriptors.FindByName('DataModule1');
  O:= [nfIsPartOfProject, nfOpenInEditor, nfCreateDefaultSrc];
  Result:= LazarusIDE.DoNewEditorFile(FD, 'main.pas','',O);
end;

{ TFreeSpiderModuleDescriptor }

constructor TFreeSpiderModuleDescriptor.Create;
begin
  inherited Create;
  Name:= 'DataModule1';
  ResourceClass:= TDataModule;
  UseCreateFormStatements:= False;
  Self.DefaultSourceName:= 'temp';
end;

function TFreeSpiderModuleDescriptor.GetLocalizedName: String;
begin
  Result:= SSpiderModuleName;
end;

function TFreeSpiderModuleDescriptor.GetLocalizedDescription: String;
begin
  Result:= SSpiderModuleDescr;
end;

function TFreeSpiderModuleDescriptor.GetInterfaceUsesSection: String;
begin
  Result:= inherited GetInterfaceUsesSection+'';
end;

function TFreeSpiderModuleDescriptor.GetImplementationSource(const Filename,
  SourceName, ResourceName: string): string;
Var
  Src : TStrings;
begin
  Src:= TStringList.Create;
  try
    Result:= inherited GetImplementationSource(Filename, SourceName, ResourceName);
    With Src do
    begin
      Add('');
      Add(Result);
      Result:=Text;
    end;
  finally
    Src.Free;
  end;
end;

end.

