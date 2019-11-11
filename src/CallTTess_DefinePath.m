function CallTTess_DefinePath(TesseroidsDirectory,BinExtension)
%CallTTess_DefinePath save .mat file with path to Tesseroids binaries
% Syntax: CallTTess_DefinePath(TesseroidsDirectory,extension)
%
% Inputs:
%    TesseroidsDirectory : path to directory containing Tesseroids binaries
%                          with trailing slash
%    BinExtension : extension of binaries filename
%                   (e.g. ".exe" on Windows, "" in *nix)
%
% 2018, Alberto Pastorutti

% check arguments
narginchk(2,2)
nargoutchk(0,0)
assert(...
    or(ischar(TesseroidsDirectory),isstring(TesseroidsDirectory)),...
    'TesseroidsDirectory must be a char/string')
assert(...
    ~isempty(TesseroidsDirectory),...
    'TesseroidsDirectory length cannot be zero')
assert(...
    or(ischar(TesseroidsDirectory),isstring(TesseroidsDirectory)),...
    'BinExtension must be a char/string (zero length is allowed)')
% check for trailing slash
if isstring(TesseroidsDirectory)
    TesseroidsDirectory = char(TesseroidsDirectory);
end
assert(...
    any(strcmp(TesseroidsDirectory(end),{'/','\'})),...
    'TesseroidsDirectory must include a trailing slash')

% write definitions
TessPathDef.TessPath = TesseroidsDirectory;
TessPathDef.TessGrd  = ['tessgrd', BinExtension];
PrismPathDef = TessPathDef; % extension and path are common
% Tesseroids
Tesspot = ['tesspot', BinExtension];
Tessgx  = ['tessgx', BinExtension];
Tessgy  = ['tessgy', BinExtension];
Tessgz  = ['tessgz', BinExtension];
Tessgxx = ['tessgxx', BinExtension];
Tessgxy = ['tessgxy', BinExtension];
Tessgxz = ['tessgxz', BinExtension];
Tessgyy = ['tessgxy', BinExtension];
Tessgyz = ['tessgyz', BinExtension];
Tessgzz = ['tessgzz', BinExtension];
% Prisms
Prismpot = ['prismpot', BinExtension];
Prismgx  = ['prismgx', BinExtension];
Prismgy  = ['prismgy', BinExtension];
Prismgz  = ['prismgz', BinExtension];
Prismgxx = ['prismgxx', BinExtension];
Prismgxy = ['prismgxy', BinExtension];
Prismgxz = ['prismgxz', BinExtension];
Prismgyy = ['prismgxy', BinExtension];
Prismgyz = ['prismgyz', BinExtension];
Prismgzz = ['prismgzz', BinExtension];

TessPathDef.ExeNames = {...
    Tesspot,...
    Tessgx ,Tessgy ,Tessgz,...
    Tessgxx,Tessgxy,Tessgxz,...
    Tessgyy,Tessgyz,Tessgzz};

PrismPathDef.ExeNames = {...
    Prismpot,...
    Prismgx ,Prismgy ,Prismgz,...
    Prismgxx,Prismgxy,Prismgxz,...
    Prismgyy,Prismgyz,Prismgzz};

% get CallTTess path and save there
CallTTess_path = which('CallTTess');
CallTTess_path = CallTTess_path(1:end-length('CallTTess.m'));
save([CallTTess_path,'TessPathDef.mat'],'TessPathDef');
save([CallTTess_path,'PrismPathDef.mat'],'PrismPathDef');

end

