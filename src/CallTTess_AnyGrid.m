function [varargout] = CallTTess_AnyGrid(GrdFile,nObs,Tess,ParFlag,VerbFlag,varargin)
%CallTTess_AnyGrid call Tesseroids binaries for tesseroids in geographic coordinates
% [uses Tesseroids: Uieda et. al 2016, doi:10.1190/geo2015-0204.1]
%
% Syntax: [(one output per functional)] = ...
%             CallTTess(...
%                 GrdFile,nObs...
%                 Tess,ParFlag,VerbFlag,...
%                 [CalcFlag])
%
% Inputs:
%    GrdFile: path to observation points file
%              in the format required by Tesseroids
%    nObs: number of observation points
%           note: no check is performed against GrdFile actual contents!
%    Tess     : n-by-7 array of tesseroid definitions
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
% 2019, Alberto Pastorutti
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
narginchk(4,5)
if nargin==5
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

nTess = size(Tess,1); % number of tesseroids

%% verbose printout
if VerbFlag==1
    fprintf([' on ( ',...
             num2str(nObs   ,'%d'),' obs * ',...
             num2str(nTess,'%d'),' tess * ',...
             num2str(nCalc  ,'%d'),' funcs ) = ',...
             num2str(nObs*nTess,'%d'),' fwd itns. \n']);
    fprintf(repmat(' ',1,length(CallDate)+3)); % CallDate string width
end

%% paths to binaries
% these are defined by the 'CallTTess_DefinePath' function
% which saves a 'TessPathDef.mat' file in the same directory of this file
TessPathDef = CallTTess_GetPath;

%% write definitions to file and perform calls to Tesseroids
out = CallTTess_SystemCalls(...
    TessPathDef.TessPath,TessPathDef.ExeNames,...
    GrdFile,nObs,Tess,ParFlag,VerbFlag,CalcFlag);

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
    fprintf(['                      actual forward time = ',...
             num2str(TimeElapsed-TimeTess),' s \n']);
    fprintf(['                      write time per tesseroid definition = ',...
             num2str(TimeTess/nTess), ' s/tess \n']);
    fprintf(['                      computation time per itn = ',...
             num2str((TimeElapsed-TimeTess)/(nTess*nObs)), ' s/itn \n']);
end

end
