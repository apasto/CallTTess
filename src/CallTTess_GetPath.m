function TessPathDef = CallTTess_GetPath
%CallTTess_GetPath
% provides a 'TessPathDef' structure
% containing the following fields:
%     - TessPath : path to Tesseroids binaries
%     - TessGrd  : name of tessgrd binary
%     - ExeNames : names of functionals (tessg*) binaries
% these are defined by the 'CallTTess_DefinePath' function
% which saves a 'TessPathDef.mat' file in the same directory of this file
narginchk(0,0)
nargoutchk(1,1)

% get path of CallTTess
CallTTess_path = which('CallTTess');
CallTTess_path = CallTTess_path(1:end-length('CallTTess.m'));

assert(...
    isfile([CallTTess_path,'TessPathDef.mat']),...
    ['TessPathDef.mat does not exist in ',CallTTess_path,...
    ' Create it using CallTTess_DefinePath']);

load([CallTTess_path,'TessPathDef.mat'],'TessPathDef');

end

