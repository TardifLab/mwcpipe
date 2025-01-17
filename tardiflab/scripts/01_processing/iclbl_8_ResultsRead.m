function ic_lblResultsRead(FILEIN) 
% Reads an xl spreadsheet into a table and translates entries in a target
% column into a list of integer values for each subject. Integer values 
% correspond to Independent Components to be removed. Values are saved
% in a comma-separated plain text file intended to be used with FSL's
% melodic for denoising of rs-fMRI data.
% 
% Notes:
% - Input should contain the FINAL JUDGMENT (remove or retain) for all ICs
%   i.e., labeling & comparison of labels from multiple raters should
%   already be completed.
% - Input should be full file path.
% - If input is multiple sheets, 1st sheet should contain FINAL JUDGMENT.
% - Output saved in same dir as input.
% - Code expects column headers to be the following:
%       IC decisions              :  "FinalJudgment_Y_remove_"
%       subject ID                :  "SUB"
%       session ID                :  "Session"
%       Independent Component ID  :  "Component"
%
%
% 2025 Mark C Nelson, McConnell Brain Imaging Centre, MNI, McGill
% -------------------------------------------------------------------------

%% ---- Setup
% Set paths
  % runloc='local'; P=a0_A2_pathDefs(runloc); addpath(genpath(P.MWC))

% Settings
  col_judgments      = 'FinalJudgment_Y_remove_';                           % final decision for each IC (keep or remove)
  col_subjectid      = {'SUB'       'SUB_1'};                               % Subject IDs from both raters
  col_sessionid      = {'Session'   'Session_1'};                           % Session IDs from both raters
  col_component      = {'Component' 'Component_1'};                         % Session IDs from both raters


% Get info about file
  [usedir,usefile]  = fileparts(FILEIN);
  
% Load file
  tfilename         = [usedir '/' usefile];
  T                 = readtable(tfilename);


%% ---- Extract data

% Remove any excess rows at the bottom
  it=0;
  while isnan(T.SUB(end))
      T(end,:)=[];
      it=it+1;
  end
  disp(['Rows removed: ' num2str(it)])


% Extract target columns
  % Nrow              = size(T,1);
  Dsubjectid        = [T.(col_subjectid{1}) T.(col_subjectid{2})];
  Dsessionid        = [T.(col_sessionid{1}) T.(col_sessionid{2})];
  Dcomponent        = [T.(col_component{1}) T.(col_component{2})];
  Djudgments        = T.(col_judgments);
  clear col_* T FILEIN it tfilename


% Confirm no mismatch between raters
  if any(Dsubjectid(:,1)~=Dsubjectid(:,2))
      error('Possible inter-rater mismatch in SUBJECT ID!')
  end
  if any(Dsessionid(:,1)~=Dsessionid(:,2))
      error('Possible inter-rater mismatch in SESSION ID!')
  end
  if any(Dcomponent(:,1)~=Dcomponent(:,2))
      error('Possible inter-rater mismatch in COMPONENT ID!')
  end


% Reduce dimensionality (if no mismatch)
  Dsubjectid=Dsubjectid(:,1);
  Dsessionid=Dsessionid(:,1);
  Dcomponent=Dcomponent(:,1);


% ------ Get info about these data

% Subject & Session info
  subjectIDs=unique(Dsubjectid)';
  sessionIDs=unique(Dsessionid)';
  % Nsub=length(subjectIDs);
  Nses=length(sessionIDs);

% Handle case of multiple sessions for some subs
  if Nses > 1
      % Find subs with multiple sessions
        subsBySession=cell(1,Nses);
        it=1;
        for ss = sessionIDs
            subsBySession{it}=unique(Dsubjectid(Dsessionid==ss));
            it=it+1;
        end
  else
      subsBySession={subjectIDs};
  end

% Output file info
  Ndataset=sum(cellfun(@(c) length(c),subsBySession));
  Dout=cell(Ndataset,2);                                                    % Output data: columns 1=Sub-Ses, 2=ICs to remove


%% ------ Read judgments & save component IDs

  it=1;
  for ii = 1:Ndataset

      tSubSesID=['sub-' sprintf('%02d',Dsubjectid(it)) '_ses-' num2str(Dsessionid(it))]; % sub-##_ses-# tag
      tinds=find(Dsubjectid==Dsubjectid(it) & Dsessionid==Dsessionid(it));               % indices for this sub & ses
      
    % Components & Judgments for this sub & ses
      tComponent=Dcomponent(tinds);                                         % indexed components from full table
      tJudgments=Djudgments(tinds);                                         % indexed judgments from full table
      tirm=cellstrfind(tJudgments,'Y');                                     % subset of indexed judgments marked for removal

    % Store data tag & components to remove
      Dout{ii,1}=tSubSesID;
      Dout{ii,2}=tComponent(tirm);

    % Advance iterators
      it=tinds(end)+1;

  end

%% ------ Save results

  outfullpath = [usedir '/ic_lblFinalOutput.txt'];
  writecell(Dout, outfullpath);                                             % Saves in directory of input file
  disp(['*-*-*  ICcompare results saved here --->  ' outfullpath])

% -------------------------------------------------------------------------
end