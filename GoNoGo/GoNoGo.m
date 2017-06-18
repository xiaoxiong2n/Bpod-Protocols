function GoNoGo

% SETUP
% > Connect the water valve in the box to Bpod Port#1.
% > Connect the air valve in the box to Bpod Port#2.
% Xiong Xiao, xiaoxiong2n@gmail.com
% Cold Spring Habor Laboratory, 04/05/2017

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmount = 5; % ul
    S.GUI.PunishAmount = 0.2; % s (air puff)
    S.GUI.TrialGoProb = 0.5;
    S.GUI.PreGoTrialNum = 4;
    
    S.GUI.ResponseTimeGo = 1; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.ResponseTimeNoGo = 1; % How long until the mouse must make a choice, or forefeit the trial
    
    S.GUI.TrainingLevel = 3; % Configurable training level
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'Habituation','Shaping', 'Task'};
    
    S.GUI.PunishDelayMean = 1;
    S.GUI.RewardDelayMean = 1;
    S.PunishDelayMax = 1.2;
    S.RewardDelayMax = 1.2;
    S.PunishDelayMin = 0.8;
    S.RewardDelayMin = 0.8;
    
    S.CueDelay = 1.0; % the time from cue to response
    S.ITI = 5;
    S.ITI_min=4; S.ITI_max=7;
    S.SoundDuration = 1.0;
    
    S.RndFlag = 1;
    
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');

%% Define trials
MaxTrials = 1000;
if S.GUI.TrainingLevel<3
    TrialTypes = ones(1,MaxTrials);
elseif S.GUI.TrainingLevel==3
    % TrialTypes = ceil(rand(1,MaxTrials)*2)-1;
    TrialTypes = ones(1,MaxTrials);
    
    for ii=(S.GUI.PreGoTrialNum+1):MaxTrials
        if rand<S.GUI.TrialGoProb
            TrialTypes(ii) = 1;
        else
            TrialTypes(ii) = 0;
        end
    end
end

R = repmat(S.GUI.PunishDelayMean,1,MaxTrials);
if S.PunishDelayMax>S.PunishDelayMin
    for k=1:MaxTrials
        candidate_delay = exprnd(S.GUI.PunishDelayMean);
        while candidate_delay>S.PunishDelayMax || candidate_delay<S.PunishDelayMin
            candidate_delay = exprnd(S.GUI.PunishDelayMean);
        end
        R(k) = candidate_delay;
    end
end
PunishDelay = R;

R = repmat(S.GUI.RewardDelayMean,1,MaxTrials);
if S.RewardDelayMax>S.RewardDelayMin
    for k=1:MaxTrials
        candidate_delay = exprnd(S.GUI.RewardDelayMean);
        while candidate_delay>S.RewardDelayMax || candidate_delay<S.RewardDelayMin
            candidate_delay = exprnd(S.GUI.RewardDelayMean);
        end
        R(k) = candidate_delay;
    end
end
RewardDelay = R;

R = repmat(S.ITI,1,MaxTrials);
for k=1:MaxTrials
    candidate_delay = exprnd(S.ITI);
    while candidate_delay>S.ITI_max || candidate_delay<S.ITI_min
        candidate_delay = exprnd(S.ITI);
    end
    R(k) = candidate_delay;
end
ITI = R;

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.TrialRewarded = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.RewardDelay = [];
BpodSystem.Data.PunishDelay = [];
BpodSystem.Data.ITI = [];
%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
GoNoGoOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',TrialTypes);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySoundX';

SF = 192000; % Sound card sampling rate
SinWaveFreq1 = 10000;
sounddata1 = GenerateSineWave(SF, SinWaveFreq1, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
SinWaveFreq2 = 3000;
sounddata2 = GenerateSineWave(SF, SinWaveFreq2, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)

% Program sound server
PsychToolboxSoundServer('init')
PsychToolboxSoundServer('Load', 1, sounddata1);
PsychToolboxSoundServer('Load', 2, sounddata2);

%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    RewardValveTime = GetValveTimes(S.GUI.RewardAmount, 1);
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % go trial
            soundID = 1;
            LickOutcome = 'Reward';
            ValveState = 1;
            ResponseTime = S.GUI.ResponseTimeGo;
        case 0 % no-go trial
            soundID = 2;
            LickOutcome = 'Punishment';
            ValveState = 2;
            ResponseTime = S.GUI.ResponseTimeNoGo;
    end
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    if S.GUI.TrainingLevel==1 % habituation
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,... % time before trial start
            'StateChangeConditions', {'Tup', 'ResponseW'},...
            'OutputActions', {'BNCState', 1});
        sma = AddState(sma, 'Name', 'ResponseW', ...
            'Timer', 15,... % reponse time window
            'StateChangeConditions', {'Port3In', 'Reward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', 0,... % reward delay
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', RewardValveTime,... % reward amount
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState}); % 'SoftCode', soundID
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    else % shaping & full task
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
            'OutputActions', {'BNC1', 1});
        sma = AddState(sma, 'Name', 'StimulusDeliver', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'CueDelay'},...
            'OutputActions', {'SoftCode', soundID});
        sma = AddState(sma, 'Name', 'CueDelay', ...
            'Timer', S.CueDelay,...
            'StateChangeConditions', {'Tup', 'ResponseW'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResponseW', ...
            'Timer', ResponseTime,...
            'StateChangeConditions', {'Port3In', LickOutcome, 'Tup', 'ITI'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', RewardDelay(currentTrial),...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Punishment', ...
            'Timer', PunishDelay(currentTrial),...
            'StateChangeConditions', {'Tup', 'DeliverPunishment'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', RewardValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'DeliverPunishment', ...
            'Timer', S.GUI.PunishAmount,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', ITI(currentTrial),...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
    end
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.RewardDelay(currentTrial) = RewardDelay(currentTrial);
        BpodSystem.Data.PunishDelay(currentTrial) = PunishDelay(currentTrial);
        BpodSystem.Data.ITI(currentTrial) = ITI(currentTrial);
        
        %Outcome
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
            BpodSystem.Data.Outcomes(currentTrial) = 1;
        elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Punishment(1))
            BpodSystem.Data.Outcomes(currentTrial) = 0;
        elseif TrialTypes(currentTrial)==1
            BpodSystem.Data.Outcomes(currentTrial) = -1;
        else
            BpodSystem.Data.Outcomes(currentTrial) = 2;
        end

        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
        UpdateGoNoGoOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

function UpdateGoNoGoOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punishment(1))
        Outcomes(x) = 0;
    elseif BpodSystem.Data.TrialTypes(x)==1
        Outcomes(x) = -1;
    else
        Outcomes(x) = 2;
    end
end
GoNoGoOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,TrialTypes,Outcomes);

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
