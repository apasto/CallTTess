function [varargout] = CallTPrism(xmin,xmax,xnum,ymin,ymax,ynum,h,Prisms,ParFlag,VerbFlag,varargin)
%CallTPrism call Tesseroids binaries for prisms in cartesian coordinates
% [uses Tesseroids: Uieda et. al 2016, doi:10.1190/geo2015-0204.1]
%
% Syntax: [(one output per functional)] = ...
%             CallTPrism(...
%                 xmin,xmax,xnum,...
%                 ymin,ymax,ynum,...
%                 h,Prisms,ParFlag,VerbFlag,...
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
%    Prisms    : n-by-7 array of tesseroid definitions
%                   [x1,x2,y1,y2,z1,z2,density]
%    ParFlag  : use parallel workers?
%    VerbFlag : verbose output? (print times)
%
% Optional Input Arguments:
%     1st optional argin = CalcFlag, vector of true/false as follows
%         [pot gx gy gz gxx gxy gxz gyy gyz gzz]
%         if missing or empty, only gz is calculated
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
    fprintf(['[',CallDate,'] CallTPrism called ']);
end

%% manage varargin and inputs
% CalcFlag
CalcFlagDefault = [0 0 0 1 0 0 0 0 0 0]; % only gz
narginchk(10,11)
if nargin==11
    CalcFlag = varargin{1};
    if isempty(CalcFlag)
        CalcFlag = CalcFlagDefault;
    elseif size(CalcFlag,1)~=1 || size(CalcFlag,2)~=10
        error('CalcFlag must be a 10 elements long vector.')
    end
    if CalcFlag == zeros(1,10)
        disp('CallTPrism: no nonzero elements in CalcFlag. Quitting.');
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
nPrisms = size(Prisms,1); % number of prisms

grdBuilder = 'tessgrd';

%% verbose printout
if VerbFlag==1
    fprintf([' on ( ',...
             num2str(nObs   ,'%d'),' obs * ',...
             num2str(nPrisms,'%d'),' prisms * ',...
             num2str(nCalc  ,'%d'),' funcs ) = ',...
             num2str(nObs*nPrisms*nCalc,'%d'),' fwd itns. \n']);
    fprintf(repmat(' ',1,length(CallDate)+3)); % CallDate string width
	fprintf(['Grid builder is ''',grdBuilder,'''.\n']);
end

%% paths to binaries
% these are defined by the 'CallTTess_DefinePath' function
% which saves a 'PrismPathDef.mat' file in the same directory of this file
PrismPathDef = CallTPrism_GetPath;

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
out = CallTPrism_SystemCalls(...
    PrismPathDef.TessPath,PrismPathDef.ExeNames,...
    TmpGrdFile,xnum*ynum,Prisms,ParFlag,VerbFlag,CalcFlag);
% since we are dealing with a rectangular, regular grid
% perform a reshape to array here
for i=1:10
    if CalcFlag(i)
        out{i} = reshape(out{i},xnum,ynum);
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
             '<strong>CallTPrism done</strong> in ',...
             num2str(TimeElapsed),' s \n']);
end

end

% Cleanup function called when cleanup objects are destroyed
% this happens on normal completition
% or due to errors, Ctrl+C by user, unforeseeable disasters, etc

function CleanGrid(TmpGrdFile)
delete(TmpGrdFile);
end
