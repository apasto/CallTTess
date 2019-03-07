function CallTTess_BuildAnyGrid(GrdFile,X,Y,Z,varargin)
%CallTTess_BuildAnyGrid(GrdFile,X,Y,Z,varargin)
nargoutchk(0,0)
narginchk(4,5)

assert(...
    isstring(GrdFile) || ischar(GrdFile),...
    'GrdFile must be provided as string or char')

% default precision: up to 5 decimal digits
DefaultWritePrec = '%.5f';
if nargin==5
    if and(ischar(varargin{1}),~isempty(varargin{1}))
        WritePrec = varargin{1};
    else
        WritePrec = DefaultWritePrec;
    end
else
    WritePrec = DefaultWritePrec;
end

% Open file
TargetFileID = fopen(GrdFile,'w');
% create onCleanup object, to fclose whatever happens
onCleanupTargetFile = onCleanup(@() GrdCloseFile(TargetFileID));

% Write header
% 5 rows, as in tessgrd output
HeaderText = ['# Grid generated with CallTTess_BuildAnyGrid.m:\n',...
              '#   local time: ',datestr(now,'yyyy-mm-dd HH:MM:ss\n'),...
              '#   total ',num2str(numel(X),'%d'),' points\n'];
fprintf(TargetFileID,HeaderText);

% Write in Tesseroids calculation point format
formatSpec = strcat(repmat([WritePrec,' '],1,3),'\n');
fprintf(TargetFileID,formatSpec,[X(:),Y(:),Z(:)]');

% fclose(TargetFileID) is not needed, since there is a onCleanup object
end

% Cleanup function called when cleanup objects are destroyed
% this happens on normal completition
% or due to errors, Ctrl+C by user, unforeseeable disasters, etc

function GrdCloseFile(Target)
fclose(Target);
end


