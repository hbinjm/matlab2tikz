function [result,msg] = eps2pdf(epsFile,fullGsPath,orientation)
%EPS2PDF Converts an eps file to a pdf file using GhostScript (GS)
%
%   [result,msg] = eps2pdf(epsFile,fullGsPath,orientation)
%
%   - epsFile:      eps file name to be converted to pdf file
%   - fullGsPath:   (optional) FULL GS path, including the file name, to
%                   the GS executable (on win32 it could be c:\program
%                   files\gs\gs8.14\bin\gswin32c.exe). The existence for
%                   fullGsPath will be checked for if given. On the other
%                   hand, if fullGsPath is not given or empty it defaults
%                   to 'gswin32c' for pcs and 'gs' for unix and the
%                   existence will not be checked for. But in this, latter
%                   case, GS's path must be in the system's path variable.
%   - orientation:  (optional) a flag that tells how the orientation tag in eps file should be treated
%                   just before the conversion (orientation tag is changed or even removed):
%                       0 -> no change (default)
%                       1 -> flip orientation
%                       2 -> remove orientation
%
%   - result:       0 if ok, anything else otherwise
%   - msg:          resulting status on file being processed
%
%   NOTES: GhostScript is needed for this function to work. Orientation can
%   also be changed - use this only if you have problems with the orientation - in
%   such a case try with orientation=1 first and then orientation=2 if the first option is
%   not the right one.
%
%   EPS2PDF converts an existing EPS file to a PDF file using Ghostscript. EPS2PDF
%   reads an eps file, modifies the bounding box and creates a pdf file whose size
%   is determined by the bounding box and not by the paper size. This can not be
%   accomplished by using Ghostscript only. So, all that one needs is of course
%   Matlab and Ghostscript drivers.
%
%   This tool is especially suited for LaTeX (TeX) users who want to create pdf
%   documents on the fly (by including pdf graphics and using either pdftex or
%   pdflatex). An example would be, if you are using LaTeX (TeX) to typeset
%   documents then the usual (simple) way to include graphics is to include eps
%   graphics using for example (if there exists myfigure.eps)
%   \begin{figure}
%       \centering
%       \includegraphics[scale=0.8]{myfigure}\\
%       \caption{some caption.}
%   \end{figure}
%   To use pdflatex (pdftex) you do not need to change anything but provide another
%   file myfigure.pdf in the same directory along with myfigure.eps. And this file,
%   of course, can be generated by EPS2PDF.
%
%   This function was tested on win32 system running Matlab R13sp1. It should work
%   on all platforms, if not, contact the author.
%
%   SOURCE:     The original idea came from the "eps-to-pdf" converter written in perl by Sebastian Rahtz
%
%   Primoz Cermelj, 24.08.2004
%   (c) Primoz Cermelj, primoz.cermelj@email.si
%
%   Version: 0.9.3
%   Last revision: 04.10.2004
%--------------------------------------------------------------------------
global epsFileContent

if ispc
    if strcmp(computer,'PCWIN64')
        DEF_GS_PATH = 'gswin64c.exe';
    else
        DEF_GS_PATH = 'gswin32c.exe';
    end
else
    DEF_GS_PATH = 'gs';
end
GS_PARAMETERS = '-q -dNOPAUSE -dBATCH -dDOINTERPOLATE -dUseFlateCompression=true -sDEVICE=pdfwrite -r1200';

narginchk(1,3);
if nargin < 2 || isempty(fullGsPath)
    fullGsPath = DEF_GS_PATH;
else
    if ~exist(fullGsPath,'dir')
        status = ['Ghostscript executable could not be found: ' fullGsPath];
        if nargout,      result = 1;    end;
        if nargout > 1,  msg = status;  else disp(status);  end;
        return
    end
end
if nargin < 3 || isempty(orientation)
    orientation = 0;
end
orientation = abs(round(orientation));
orientation = orientation(1);
if orientation < 0 || orientation > 2
    orientation = 0;
end

epsFileContent = [];

%---------
% Get file name, path
%---------
source = epsFile;
[pathstr,sourceName,ext] = fileparts(source);
if isempty(pathstr)
    pathstr = cd;
    source = fullfile(pathstr,source);
end

targetName = [sourceName '.pdf'];
target = fullfile(pathstr,targetName);    % target - pdf file

tmpFileName = sourceName;
tmpFile = fullfile(pathstr,[tmpFileName ext '.eps2pdf~']);


% Create tmp file,...
[ok,errStr] = create_tmpepsfile(source,tmpFile,orientation);
if ~ok
    status = ['Error while creating temporary eps file: ' epsFile ' - ' errStr];
    if nargout,      result = 1;    end;
    if nargout > 1,  msg = status;  else disp(status); end;
else
    % Run Ghostscript
    comandLine = ['"' fullGsPath '"' ' ' GS_PARAMETERS ' -sOutputFile=' '"' target '"' ' -f ' '"' tmpFile '"'];
    [stat, result] = system(comandLine);
    if stat
        status = ['pdf file not created - error running Ghostscript - check GS path: ' result];
        if nargout,      result = 1;    end;
        if nargout > 1,  msg = status;  else disp(status);  end;
    else
        status = 'pdf successfully created';
        if nargout,      result = 0;    end;
        if nargout > 1,  msg = status;  else disp(status);  end;
    end
end

% Delete tmp file
if exist(tmpFile,'file')
    delete(tmpFile);
end






%/////////////////////////////////////////////////////////////////////
%                       SUBFUNCTIONS SECTION
%/////////////////////////////////////////////////////////////////////

%--------------------------------------------------------------------
function [ok,errStr] = create_tmpepsfile(epsFile,tmpFile,orientation)
% Creates tmp eps file - file with refined content
global epsFileContent

[ok,errStr] = read_epsfilecontent( epsFile );
if ~ok
    return
end
[ok,errStr] = update_epsfilecontent( epsFile,orientation );
if ~ok
    return
end
fh = fopen(tmpFile,'w');
if fh == -1
    errStr = ['Temporary file cannot be created. Check write permissions.'];
    return
end
try
    fwrite(fh,epsFileContent,'char');  % fwrite is faster than fprintf
    ok = 1;
catch
    errStr = ['Error writing temporary file. Check write permissions.'];
end
fclose(fh);
%--------------------------------------------------------------------


%--------------------------------------------------------------------
function [ok,errStr] = read_epsfilecontent( epsFile )
% Reads the content of the eps file into epsFileContent
global epsFileContent

ok = 0;
errStr = [];
fh = fopen(epsFile,'r');
if fh == -1
    errStr = ['File: ' epsFile ' cannot be accessed or does not exist'];
    return
end
try
    epsFileContent = fread(fh,'char=>char')';       % fread is faster than fscanf
    ok = 1;
catch
    errStr = lasterror;
end
fclose(fh);
%--------------------------------------------------------------------


%--------------------------------------------------------------------
function [ok,errStr] = update_epsfilecontent(epsFile,orientation)
% Updates eps file by adding some additional information into the header
% section concerning the bounding box (BB)
global epsFileContent

ok = 0;
errStr = [];

% Read current BB coordinates
ind = strfind( lower(epsFileContent), lower('%%BoundingBox:'));
if isempty(ind)
    errStr = ['Cannot find Bounding Box in file: ' epsFile];
    return
end
ii = ind(1) + 14;
fromBB = ii;
while ~((epsFileContent(ii) == sprintf('\n')) || (epsFileContent(ii) == sprintf('\r')) || (epsFileContent(ii) == '%'))
    ii = ii + 1;
end
toBB = ii - 1;
coordsStr = epsFileContent(fromBB:toBB);
coords = str2num( coordsStr );
if isempty(coords)
    errStr = ['Error reading BB coordinates from file: ' epsFile];
    return
end
NL = getnl;
w = abs(coords(3)-coords(1));
h = abs(coords(4)-coords(2));

% Change the orientation if requested
changeOrientation = 0;
if orientation ~= 0
    ind = strfind( lower(epsFileContent), lower('%%Orientation:'));
    if ~isempty(ind)
        ii = ind(1) + 14;
        fromOR = ii;
        while ~((epsFileContent(ii) == sprintf('\n')) || (epsFileContent(ii) == sprintf('\r')) || (epsFileContent(ii) == '%'))
            ii = ii + 1;
        end
        toOR = ii - 1;
        orientStr = strim(epsFileContent(fromOR:toOR));
        if ~isempty(orientStr) && orientation == 1           % flip
            if strfind(lower(orientStr),'landscape')
                changeOrientation = 1;
                orientStr = 'Portrait';
            elseif strfind(lower(orientStr),'portrait')
                changeOrientation = 1;
                orientStr = 'Landscape';
            end
        elseif  ~isempty(orientStr) && orientation == 2      % remove
            if strfind(lower(orientStr),'landscape') || strfind(lower(orientStr),'portrait')
                changeOrientation = 1;
                orientStr = ' ';
            end
        end
    end
end

% Refine the content - add additional information and even change the
% orientation
addBBContent = [' 0 0 ' int2str(w) ' ' int2str(h) ' ' NL...
                    '<< /PageSize [' int2str(w) ' ' int2str(h) '] >> setpagedevice' NL...
                    'gsave ' int2str(-coords(1)) ' ' int2str(-coords(2)) ' translate'];
if changeOrientation
    if fromOR > fromBB
        epsFileContent = [epsFileContent(1:fromBB-1) addBBContent epsFileContent(toBB+1:fromOR-1) orientStr epsFileContent(toOR+1:end)];
    else
        epsFileContent = [epsFileContent(1:fromOR-1) orientStr epsFileContent(toOR+1:fromBB-1) addBBContent epsFileContent(toBB+1:end)];
    end
else
    epsFileContent = [epsFileContent(1:fromBB-1) addBBContent  epsFileContent(toBB+1:end)];
end

ok = 1;
%--------------------------------------------------------------------

%--------------------------------------------------------------------
function NL = getnl
% Returns new-line string as found from first occurance from epsFileContent
global epsFileContent

NL = '\r\n';        % default (for Windows systems)
ii = 1;
len = length(epsFileContent);
while ~(epsFileContent(ii)==sprintf('\n') || epsFileContent(ii)==sprintf('\r') || ii<len)
    ii = ii + 1;
end
if epsFileContent(ii)==sprintf('\n')
    NL = '\n';
elseif epsFileContent(ii)==sprintf('\r')
    NL = '\r';
    if epsFileContent(ii+1)==sprintf('\n')
        NL = [NL '\n'];
    end
end
NL = sprintf(NL);
%--------------------------------------------------------------------


%--------------------------------------------------------------------
function outstr = strim(str)
% Removes leading and trailing spaces (spaces, tabs, endlines,...)
% from the str string.
if isnumeric(str);
    outstr = str;
    return
end
ind = find( ~isspace(str) );        % indices of the non-space characters in the str
if isempty(ind)
    outstr = [];
else
    outstr = str( ind(1):ind(end) );
end
%--------------------------------------------------------------------
