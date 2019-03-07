function [varargout] = CallTTess(xmin,xmax,xnum,ymin,ymax,ynum,h,Tess,ParFlag,VerbFlag,varargin)
%CallTTess call Tesseroids binaries for tesseroids in geographic coordinates
% [uses Tesseroids: Uieda et. al 2016, doi:10.1190/geo2015-0204.1]
%
% Syntax: [(one output per functional)] = ...
%             CallTTess(...
%                 xmin,xmax,xnum,...
%                 ymin,ymax,ynum,...
%                 h,Tess,ParFlag,VerbFlag,...
%                 [CalcFlag,grdBuilder,referenceEllipsoid])
%
% Inputs:
%    observation grid definition:
%        these can be either spherical or ellipsoidal coordinates
%        default is spherical, using Tesseroids reference sphere
%        see 2nd optional argument to use ellipsoidal coordinates
%            xmin,xmax,xnum : coords along Lon: start, stop, number
%            ymin,ymax,ynum : coords along Lat: start, stop, number
%            h : observation height
%    Tess     : n-by-7 array of tesseroid definitions
%                   [x1,x2,y1,y2,z1,z2,density]
%    ParFlag  : use parallel workers?
%    VerbFlag : verbose output? (print times)
%
% Optional Input Arguments:
%     1st optional argin = CalcFlag, vector of true/false as follows
%         [pot gx gy gz gxx gxy gxz gyy gyz gzz]
%         if missing or empty, only gz is calculated
%     2nd optional argin: type of grid builder (case insensitive)
%         'tessgrd'    : default, use Tesseroids binary, grid on spherical coordinates
%         'TessGrdEll' : convert input ellipsoidal coordinates to spherical
%     3rd optional argin: referenceEllipsoid object, needed for 'TessGrdEll'  
%
% Outputs:
%    one output array for each functional requested in CalcFlag
%
% 2018, Alberto Pastorutti
%


%% timing
% only used for verbose output
if VerbFlag==1
    CallDate = datestr(now,'yyyy-mm-ddTHH:MM:ss');
    TimeStart = tic;
    fprintf(['[',CallDate,'] CallTTess called ']);
end

%% manage varargin and inputs
% CalcFlag
CalcFlagDefault = [0 0 0 1 0 0 0 0 0 0]; % only gz
narginchk(10,13)
if nargin>=11
    CalcFlag = varargin{1};
    if isempty(CalcFlag)
        CalcFlag = CalcFlagDefault;
    elseif size(CalcFlag,1)~=1 || size(CalcFlag,2)~=10
        error('CalcFlag must be a 10 elements long vector.')
    end
    if CalcFlag == zeros(1,10)
        disp('CallTTess: no nonzero elements in CalcFlag. Quitting.');
        for i=1:nargout
            varargout{i}=NaN; %#ok<AGROW>
        end
        return
    end
else
    CalcFlag = CalcFlagDefault;
end

nCalc = numel(find(CalcFlag==1)); % number of computed functionals
nargoutchk(nCalc,nCalc);

nObs = xnum*ynum; % number of observations
nTess = size(Tess,1); % number of tesseroids

% type of grid builder
if nargin>=12
    assert(ischar(varargin{2}),' grid builder type must be a char array.')
    switch lower(varargin{2}) % case insensitive
        case 'tessgrd'
            grdBuilder = 'tessgrd';
        case lower('TessGrdEll')
            grdBuilder = 'TessGrdEll';
            assert(nargin==13,'TessGrdEll needs a referenceEllipsoid. Argument 13 is missing.')
            assert(isa(varargin{3},'referenceEllipsoid'),... % 'isa' equals to strcmp(class(x),'classname')
                   ['TessGrdEll needs a referenceEllipsoid. Argument 13 is a ',class(varargin{3})])
            EllRef = varargin{3};
        otherwise
            error(['''',varargin{1},''' is not an allowed grid builder option.'])
    end
else
    grdBuilder = 'tessgrd';
end

%% verbose printout
if VerbFlag==1
    fprintf([' on ( ',...
             num2str(nObs   ,'%d'),' obs * ',...
             num2str(nTess,'%d'),' tess * ',...
             num2str(nCalc  ,'%d'),' funcs ) = ',...
             num2str(nObs*nTess,'%d'),' fwd itns. \n']);
    fprintf(repmat(' ',1,length(CallDate)+3)); % CallDate string width
	fprintf(['Grid builder is ''',grdBuilder,'''']);
    if strcmp(grdBuilder,'TessGrdEll')
        fprintf([' with ellipsoid ''',EllRef.Name,'''.\n']);
    else
        fprintf('. Input coords considered already spherical.\n');
    end
end

%% paths to binaries
% these are defined by the 'CallTTess_DefinePath' function
% which saves a 'TessPathDef.mat' file in the same directory of this file
TessPathDef = CallTTess_GetPath;

%% build observation grid
% rectangular and regular
TmpGrdFile = 'TmpGrd.txt';
% create onCleanup object
onCleanupGRID = onCleanup(@() CleanGrid(TmpGrdFile));

CallTTess_BuildRectGrid(...
    xmin,xmax,xnum,...
    ymin,ymax,ynum,...
    h,TmpGrdFile,grdBuilder);

%% write definitions to file and perform calls to Tesseroids
out = CallTTess_SystemCalls(...
    TessPathDef.TessPath,TessPathDef.ExeNames,...
    TmpGrdFile,xnum*ynum,Tess,ParFlag,VerbFlag,CalcFlag);
% since we are dealing with a rectangular, regular grid
% perform a reshape to array here
for i=1:10
    if CalcFlag(i)
        reshape(out{i},xnum,ynum);
    end
end

%% discard empty outputs and write to varagout
count = 1;
for i=1:10
    if ~isempty(out{i})
        varargout{count} = out{i}; %#ok<AGROW>
        count = count+1;
    end
end

%% verbose output
TimeElapsed = toc(TimeStart);

if VerbFlag==1
    fprintf(['[',datestr(now,'yyyy-mm-ddTHH:MM:ss'),'] ',...
             ' <strong>CallTTess done</strong> in ',...
             num2str(nTess,'%d'),' tess built in ',...
             num2str(TimeElapsed),' s \n']);
end

end

% Cleanup function called when cleanup objects are destroyed
% this happens on normal completition
% or due to errors, Ctrl+C by user, unforeseeable disasters, etc

function CleanGrid(TmpGrdFile)
delete(TmpGrdFile);
end
