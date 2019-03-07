function [varargout] = CallTTess(xmin,xmax,xnum,ymin,ymax,ynum,h,Tess,ParFlag,VerbFlag,varargin)
%CallTTess
% call Tesseroids binaries for tesseroids in geographic coordinates
% from (and to) Matlab
% [Tesseroids: Uieda et. al 2016, doi:10.1190/geo2015-0204.1]
% 1st optional argin = CalcFlag, vector of true/false as follows
%     [pot gx gy gz gxx gxy gxz gyy gyz gzz]
%     if missing or empty, only gz is calculated
% 2nd optional argin: type of grid builder (case insensitive)
%     'tessgrd'    : default, use Tesseroids binary, grid on spherical coordinates
%     'TessGrdEll' : convert input ellipsoidal coordinates to spherical
% 3rd optional argin: referenceEllipsoid object, needed for 'TessGrdEll'

%% timing
% only used for verbose output
if VerbFlag==1
    CallDate = datestr(now,'yyyy-mm-ddTHH:MM:ss');
    TimeStart = tic;
    fprintf(['[',CallDate,'] CallTTess called ']);
end

%% manage varargin and inputs
% CalcFlag
CalcFlagDefault = [0 0 0 1 0 0 0 0 0 0];
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

% get path of CallTTess
CallTTess_path = which('CallTTess');
CallTTess_path = CallTTess_path(1:end-length('CallTTess.m'));

assert(...
    isfile([CallTTess_path,'TessPathDef.mat']),...
    ['TessPathDef.mat does not exist in ',CallTTess_path,...
    ' Create it using CallTTess_DefinePath']);

load([CallTTess_path,'TessPathDef.mat'],'TessPathDef.TessPathDef');

%% build observation grid
% calling Tesseroids, it is way faster to write to a file and read from it
TmpGrdFile = 'TmpGrd.txt';
% create onCleanup object
onCleanupGRID = onCleanup(@() CleanGrid(TmpGrdFile));

switch grdBuilder
    case 'tessgrd'
        [GrdStatus,GrdCmdout] = system([TessPathDef.TessPath,TessPathDef.TessGrd,' -v -r',...
                                        num2str(xmin,'%i'),'/',num2str(xmax,'%i'),'/',...
                                        num2str(ymin,'%i'),'/',num2str(ymax,'%i'),' -b',...
                                        num2str(xnum,'%i'),'/',num2str(ynum,'%i'),...
                                        ' -z',num2str(h,'%i'),' > ',TmpGrdFile]);
        if GrdStatus~=0
            disp(['Output of system call to ',TessPathDef.TessGrd]);
            disp(GrdCmdout);
            error([TessPathDef.TessGrd,' exited with nonzero status. Quitting.']);
        end
    case 'TessGrdEll'
        xstep = (xmax-xmin)/(xnum-1);
        ystep = (ymax-ymin)/(ynum-1);
        TessGrdEll(TmpGrdFile,ymin,ymax,ystep,xmin,xmax,xstep,h,EllRef)
end

%% write tesseroids definitions to temporary file
% precision is up to 5 decimal digits
WritePrec = '%.5f';

% split tesseroids in input to each parallel worker
% for each parallel worker a separate temporary text file
if ParFlag==1 && license('test','Distrib_Computing_Toolbox')
    Pool = gcp('nocreate'); % get current parpool, if there is any already
    if isempty(Pool) % no parpool running? create one
        Pool = parpool('local');
    end
    ParWorkers = Pool.NumWorkers;
    if size(Tess,1)<=ParWorkers % is there less than a tesseroid per worker?
        ParWorkers = 1;
    end
else
    ParWorkers = 1;
end
TmpTessFile = cell(1,ParWorkers);

if ParWorkers~=1
    % first file gets TessToEach plus remainder after division
    TessToEach = ones(1,ParWorkers)*(floor(size(Tess,1)/ParWorkers));
    TessToEach(1) = TessToEach(2)+rem(size(Tess,1),ParWorkers); % tess to first
    for p=1:ParWorkers
        TmpTessFile{p} = ['TmpTess_par',num2str(p,'%i'),'.txt'];
    end
    dlmwrite(TmpTessFile{1},...
        Tess(1:TessToEach(1),:),...
        'delimiter',' ','precision',WritePrec);
    for p=2:ParWorkers
        dlmwrite(TmpTessFile{p},...
            Tess(TessToEach(1)+(1:TessToEach(p))+TessToEach(p)*(p-2),:),...
            'delimiter',' ','precision',WritePrec);
    end
    % split happens correctly: conserves numbers of elements and total mass
else
    TmpTessFile{1} = 'TmpTess_1.txt';
    dlmwrite(TmpTessFile{1},...
             Tess,...
             'delimiter',' ','precision',WritePrec);
end

% create onCleanup object
onCleanupPRISMS = onCleanup(@() CleanTess(TmpTessFile,ParWorkers));

%% verbose output of called function, date, and calculated functionals
TimeTess = toc(TimeStart);

if VerbFlag==1
    fprintf(['[',datestr(now,'yyyy-mm-ddTHH:MM:ss'),'] ',...
             num2str(nTess,'%d'),' tess built in ',...
             num2str(TimeTess),' s \n']);
end

%% call tesseroid effect calculations
% then load text output of computations, sum and reshape

% declaration of function to import text
    function ReadOut = ReadTxt(filename)
        delimiter = ' ';
        startRow = 12; % this is due to Tesseroids output header
        endRow = startRow + ynum*xnum;
        formatSpec = '%*s%*s%*s%f%*s%*s%*s%*s%[^\n\r]';
        fileID = fopen(filename,'r');
        textscan(fileID, '%[^\n\r]', startRow-1, 'WhiteSpace', '',...
                 'ReturnOnError', false);
        dataArray = textscan(fileID, formatSpec, endRow-startRow+1,...
                             'Delimiter', delimiter,...
                             'MultipleDelimsAsOne', true,...
                             'TextType', 'string',...
                             'EmptyValue', NaN,...
                             'ReturnOnError', false,...
                             'EndOfLine', '\r\n');
        fclose(fileID);
        ReadOut = [dataArray{1:end-1}];
    end

CalcStatus = NaN(10,ParWorkers);
CalcCmdout = cell(10,ParWorkers);
CalcNames = {'pot','gx','gy','gz','gxx','gxy','gxz','gyy','gyz','gzz'};
TmpOutFile = cell(10,ParWorkers);
for i=1:10
    for p=1:ParWorkers
        TmpOutFile{i,p} = ['TmpOutFile_',CalcNames{i},'_par',num2str(p,'%i'),'.txt'];
    end
end

% create onCleanup object
onCleanupOUT = onCleanup(@() CleanOutput(TmpOutFile,ParWorkers));

% generic call to functional
    function out = CalcFunctional(CF,CFname)
        % documentare
        out_split = NaN(ParWorkers,ynum*xnum);
        if CalcFlag(CF)==1
            if ParWorkers~=1
                parfor PP=1:ParWorkers
                    [CalcStatus(CF,PP),CalcCmdout{CF,PP}] = ...
                        system([TessPathDef.TessPath,CFname,' -v ',...
                                TmpTessFile{PP},' < ',TmpGrdFile,...
                                ' > ' TmpOutFile{CF,PP}]);
                end
            else
                [CalcStatus(CF,1),CalcCmdout{CF,1}] = ...
                    system([TessPathDef.TessPath,CFname,' -v ',...
                            TmpTessFile{1},' < ',TmpGrdFile,...
                            ' > ' TmpOutFile{CF,1}]);
            end
            if any(CalcStatus(CF,:))
                disp(['Output of system call to ',CFname]);
                for PP=find(CalcStatus(CF,:))
                    disp(['[Worker number ',num2str(PP,'%i'),']']);
                    disp(CalcCmdout{CF,PP});
                end
                error([CFname,' exited with nonzero status. Quitting.']);
            end
            for PP=1:ParWorkers
                out_split(PP,:) = ReadTxt(TmpOutFile{CF,PP});
            end
            out = sum(out_split,1);
            out = reshape(out,xnum,ynum);
        else
            out = [];
        end
    end

out = cell(1,10);
for i=1:10
    out{i} = CalcFunctional(i,TessPathDef.ExeNames{i});
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
    fprintf(['                      actual forward time = ',...
             num2str(TimeElapsed-TimeTess),' s \n']);
    fprintf(['                      write time per tesseroid definition = ',...
             num2str(TimeTess/nTess), ' s/tess \n']);
    fprintf(['                      computation time per itn = ',...
             num2str((TimeElapsed-TimeTess)/(nTess*nObs)), ' s/itn \n']);
end

end

% Cleanup functions for CallTTess
% called when cleanup objects are destroyed
% this happens due to clean exit, error, Ctrl+C by user...

function CleanGrid(TmpGrdFile)
delete(TmpGrdFile);
end

function CleanTess(TmpTessFile,ParWorkers)
for p=1:ParWorkers
    delete(TmpTessFile{p});
end
end

function CleanOutput(TmpOutFile,ParWorkers)
% Since we are not always calculating all the functionals,
% this can give lot of "file does not exist" warnings.
% Calling delete only on existing files
% would be an unnecessary complication.
% Solution: we mute the FileNotFound
% Save current state of file not found warning, then turn it off
WarnStruct = warning('query','MATLAB:DELETE:FileNotFound');
warning('off','MATLAB:DELETE:FileNotFound');
for i=1:10
    for p=1:ParWorkers
        delete(TmpOutFile{i,p});
    end
end
% turn warning back to its previous state (state can be 'on' or 'off')
warning(WarnStruct.state,'MATLAB:DELETE:FileNotFound');
end


% embedded function: TessGrdEll
function TessGrdEll(TargetFile,LatMin,LatMax,LatStep,LonMin,LonMax,LonStep,Height,Ell_ref)
%TessGrdEll Build Tesseroid grid defined in ellipsoidal coords, then
%           converted to spherical coords and height respect to equatorial radius
%   TessGrdEll(TargetFile,LatMin,LatMax,LatStep,LonMin,LonMax,LonStep,Height,Ell_ref)

nargoutchk(0,0)
narginchk(9,9)

% referenceSphere: hardcoded to Tesseroids, equatorial radius
Sph_ref = referenceSphere('earth');
Sph_ref.Radius = 6378137; % from src/lib/constant.c in Tesseroids 1.2.1

% Build regular grid
% longitudes do not need ell2sph transformation
LonV = LonMin:LonStep:LonMax;

Ell_LatV = LatMin:LatStep:LatMax;
% transform latitudes into spherical latitudes
[Sph_LatV,~,Sph_HeightsV] = ell2sph(Ell_LatV,zeros(size(Ell_LatV)),ones(size(Ell_LatV))*Height,...
                                    Ell_ref,Sph_ref);

[Sph_Mesh_Lon,Sph_Mesh_Lat] = meshgrid(LonV,Sph_LatV);
Sph_Mesh_Heights = Sph_HeightsV' * ones(size(LonV));

% Open file
TargetFileID = fopen(TargetFile,'w');
% create onCleanup object
onCleanupTargetFile = onCleanup(@() TessGrdEllCloseFile(TargetFileID));

% Write header
% 5 rows, as in tessgrd output
HeaderText = ['# Grid generated with TessGrdEll.m:\n',...
              '#   local time: ',datestr(now,'yyyy-mm-dd HH:MM:ss\n'),...
              '#   ell(Lat min=',num2str(LatMin),' max=',num2str(LatMax),')',...
                 ' sph(Lat min=',num2str(min(Sph_LatV)),' max=',num2str(max(Sph_LatV)),')',...
                 ' Lon min=',num2str(LonMin),' max=',num2str(LonMax),...
                 ' ell_h=',num2str(Height),' ell=',Ell_ref.Name,'\n',...
              '#   grid spacing: ',num2str(LonStep),' lon / ',num2str(LatStep), ' lat\n',...
              '#   grid size: ',num2str(size(Sph_Mesh_Lon,1),'%u'),' x ',num2str(size(Sph_Mesh_Lon,2),'%u'),...
                 ', total ',num2str(numel(Sph_Mesh_Lon),'%d'),' points\n'];
fprintf(TargetFileID,HeaderText);

% Write in Tesseroids calculation point format
% 5 decimal digits precision deemed enough for purpose
formatSpec = strcat(repmat('%.5f ',1,3),'\n');
fprintf(TargetFileID,formatSpec,...
        [Sph_Mesh_Lon(:),Sph_Mesh_Lat(:),Sph_Mesh_Heights(:)]');

% fclose(TargetFileID) is not needed, since there is a onCleanup object

end

% Cleanup function for TessGrdEll, called when cleanup objects are destroyed
% this happens on normal completition
% or due to errors, Ctrl+C by user, unforeseeable disasters, etc
function TessGrdEllCloseFile(Target)
fclose(Target);
end
