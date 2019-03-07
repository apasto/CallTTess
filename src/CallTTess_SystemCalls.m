function out = CallTTess_SystemCalls(TessPath,ExeNames,TmpGrdFile,nObs,Tess,ParFlag,VerbFlag,CalcFlag,varargin)
%CallTTess_SystemCalls

if VerbFlag==1
    TimeStartTess = tic;
end

%% write tesseroids definitions to temporary file
% default precision: up to 5 decimal digits
DefaultWritePrec = '%.5f';
if nargin==9
    if and(ischar(varargin{1}),~isempty(varargin{1}))
        WritePrec = varargin{1};
    else
        WritePrec = DefaultWritePrec;
    end
else
    WritePrec = DefaultWritePrec;
end

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

%% verbose output of time needed to write out tesseroids
if VerbFlag==1
    TimeTess = toc(TimeStartTess);
    fprintf(['[',datestr(now,'yyyy-mm-ddTHH:MM:ss'),'] ',...
             num2str(size(Tess,1),'%d'),' tess built in ',...
             num2str(TimeTess),' s \n']);
end

%% call tesseroid effect calculations
% then load text output of computations, sum and reshape

% declaration of function to import text
    function ReadOut = ReadTxt(filename)
        delimiter = ' ';
        startRow = 12; % this is due to Tesseroids output header
        endRow = startRow + nObs;
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
        out_split = NaN(ParWorkers,nObs);
        if CalcFlag(CF)==1
            if ParWorkers~=1
                parfor PP=1:ParWorkers
                    [CalcStatus(CF,PP),CalcCmdout{CF,PP}] = ...
                        system([TessPath,CFname,' -v ',...
                                TmpTessFile{PP},' < ',TmpGrdFile,...
                                ' > ' TmpOutFile{CF,PP}]);
                end
            else
                [CalcStatus(CF,1),CalcCmdout{CF,1}] = ...
                    system([TessPath,CFname,' -v ',...
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
        else
            out = [];
        end
    end

out = cell(1,10);
for i=1:10
    out{i} = CalcFunctional(i,ExeNames{i});
end

end

% Cleanup functions
% called when cleanup objects are destroyed
% this happens due to clean exit, error, Ctrl+C by user...

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
