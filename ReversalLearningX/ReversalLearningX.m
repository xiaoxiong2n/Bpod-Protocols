function ReversalLearningX
% This protocol is for head-fixed reversal learning task
% SETUP
% > Connect the left water valve in the box to Bpod Port#1.
% > Connect the right water valve in the box to Bpod Port#2.
% > Connect the left lick detector in the box to Bpod Port#3.
% > Connect the right lick detector in the box to Bpod Port#4.
% > Connect the air valve in the box to Bpod Port#5.
% > Xiong Xiao,04/08/2017, CSHL (Bo Li lab)
% > xiaoxiong2n@gmail.com

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmountLeft = 7; % ul
    S.GUI.RewardAmountRight = 5; % ul
    S.GUI.PunishAmount = 0.1; % s (air puff)
    S.GUI.LeftSideProb = 0.5;
    
    S.GUI.ResponseTime = 4; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.ResponseDelay = 0.2;
    S.GUI.PunishDelayMean = 0.1;
    S.GUI.RewardDelayMean = 0.1;
    
    S.GUI.TrainingLevel = 1; % Configurable training level
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'Habituation','Shaping', 'Task'};
    
    S.SoundDuration = 1.0;
    S.ITI_mean = 3;
    S.ITI_min = 4;
    S.ITI_max = 7;
    
    % 1: cue A, left; cue B, right (for normal training)
    % 2: cue A, right; cue B, left (for reversal training)
    % 3: change from SideCode 1 to 2, 2 to 1 (randomly)
    S.SideCodeFlag = 1;
    S.AccuracyCutoff = 0.8;
    
    S.ReTeaching = 0;
    
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');
%% Define trials
% TrialType = 1 : cue A ; TrialType = 2 : cue B
MaxTrials = 1000;
if S.GUI.TrainingLevel==1
    TrialRepeatNum = 5;
    type_rand = ceil(rand*2);
    TrialTypes0 = [repmat(type_rand,1,TrialRepeatNum),repmat(3-type_rand,1,TrialRepeatNum)];
    TrialTypes = repmat(TrialTypes0,1,MaxTrials/(2*TrialRepeatNum));
    %TrialTypes = ones(1,MaxTrials);
    %TrialTypes = 2*ones(1,MaxTrials);
else
    if S.GUI.LeftSideProb == 0.5
        TrialTypes = ceil(rand(1,MaxTrials)*2);
    else
        for ii=1:MaxTrials
            if rand<S.GUI.LeftSideProb
                TrialTypes(ii) = 1;
            else
                TrialTypes(ii) = 2;
            end
        end
    end
end

switch S.SideCodeFlag
    case 1
        SideCode=ones(1,MaxTrials);
    case 2
        SideCode=2*ones(1,MaxTrials);
    case 3
        %SideCode=ceil(rand*2)*ones(1,MaxTrials);
        SideCode=ones(1,MaxTrials);
end

R = repmat(S.ITI_mean,1,MaxTrials);
for k=1:MaxTrials
    candidate_delay = exprnd(S.ITI_mean);
    while candidate_delay>S.ITI_max || candidate_delay<S.ITI_min
        candidate_delay = exprnd(S.ITI_mean);
    end
    R(k) = candidate_delay;
end
ITI = R;

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.Outcomes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.ITI = []; % ITI
BpodSystem.Data.SideCode = []; % SideCode
%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';

SF = 192000; % Sound card sampling rate
SinWaveFreq1 = 8000;
SinWaveFreq2 = 1000;
sounddata1 = GenerateSineWave(SF, SinWaveFreq1, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
sounddata2 = GenerateSineWave(SF, SinWaveFreq2, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)

% Program sound server
PsychToolboxSoundServer('init')
PsychToolboxSoundServer('Load', 1, sounddata1);
PsychToolboxSoundServer('Load', 2, sounddata2);
%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R(1) = GetValveTimes(S.GUI.RewardAmountLeft, 1);
    R(2) = GetValveTimes(S.GUI.RewardAmountRight, 2);
    LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
    
    if S.SideCodeFlag==3
        AccuracyP = 0;
        if currentTrial>40
            temp_side = unique(SideCode(currentTrial-30:currentTrial-1));
            if length(temp_side)<2
                temp_outcome = BpodSystem.Data.Outcomes(currentTrial-30:currentTrial-1);
                AccuracyP = sum(temp_outcome==1)./length(temp_outcome);
            end
        end
        
        if AccuracyP>=S.AccuracyCutoff % reversal
            SideCode(currentTrial:end)=3-SideCode(currentTrial-1);
        end
    end
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % cue A
            soundID = 1;
            if SideCode==1
                LickOutcomeA = 'Reward';
                LickOutcomeB = 'Punishment';
                ValveState = 1;
                ValveTime = LeftValveTime;
            else
                LickOutcomeA = 'Punishment';
                LickOutcomeB = 'Reward';
                ValveState = 2;
                ValveTime = RightValveTime;
            end
            
        case 2 % cue B
            soundID = 2;
            if SideCode==1
                LickOutcomeA = 'Punishment';
                LickOutcomeB = 'Reward';
                ValveState = 2;
                ValveTime = RightValveTime;
            else
                LickOutcomeA = 'Reward';
                LickOutcomeB = 'Punishment';
                ValveState = 1;
                ValveTime = LeftValveTime;
            end
    end
    
    if S.GUI.TrainingLevel==1
        switch TrialTypes(currentTrial)
            case 1 % left port is rewarded
                ResponseArgument = {'Port3In','Reward','Tup','SmallReward'};
            case 2 % right port is rewarded
                ResponseArgument = {'Port4In','Reward','Tup','SmallReward'};
        end
        ErrorReinforcer = {'Tup', 'SmallReward'};
    elseif S.GUI.TrainingLevel==2
        switch TrialTypes(currentTrial)
            case 1 % left port is rewarded
                ResponseArgument = {'Port3In', LickOutcomeA, 'Tup', 'SmallReward'};
            case 2 % right port is rewarded
                ResponseArgument = {'Port4In', LickOutcomeB, 'Tup', 'SmallReward'};
        end
        ErrorReinforcer = {'Tup', 'SmallReward'};
    elseif S.GUI.TrainingLevel==3
        ResponseArgument = {'Port3In', LickOutcomeA, 'Port4In', LickOutcomeB, 'Tup', 'ITI'};
        ErrorReinforcer = {'Tup', 'DeliverPunishment'};
    end
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    if S.GUI.TrainingLevel==1 % habituation
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
            'OutputActions', {'BNCState', 1});
        sma = AddState(sma, 'Name', 'StimulusDeliver', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'CueDelay'},...
            'OutputActions', {'SoftCode', soundID});
        sma = AddState(sma, 'Name', 'CueDelay', ...
            'Timer', S.SoundDuration,...
            'StateChangeConditions', {'Tup', 'Reward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.GUI.RewardDelayMean,...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Punishment', ...
            'Timer', S.GUI.PunishDelayMean,...
            'StateChangeConditions', ErrorReinforcer,...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', ValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'DeliverPunishment', ...
            'Timer', S.GUI.PunishAmount,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', 4});
        sma = AddState(sma, 'Name', 'SmallReward', ...
            'Timer', S.GUI.RewardDelayMean,...
            'StateChangeConditions', {'Tup', 'DeliverSmallReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverSmallReward', ...
            'Timer', ValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    else % shaping & full task
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
            'OutputActions', {'BNCState', 1});
        sma = AddState(sma, 'Name', 'StimulusDeliver', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'CueDelay'},...
            'OutputActions', {'SoftCode', soundID});
        sma = AddState(sma, 'Name', 'CueDelay', ...
            'Timer', S.SoundDuration+S.GUI.ResponseDelay,...
            'StateChangeConditions', {'Tup', 'ResponseCue'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResponseCue', ...
            'Timer', 0.2,...
            'StateChangeConditions', {'Tup', 'ResponseW'},...
            'OutputActions', {'PWM1', 64,'PWM2', 64});
        sma = AddState(sma, 'Name', 'ResponseW', ...
            'Timer', S.GUI.ResponseTime,...
            'StateChangeConditions', ResponseArgument,...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.GUI.RewardDelayMean,...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Punishment', ...
            'Timer', S.GUI.PunishDelayMean,...
            'StateChangeConditions', ErrorReinforcer,...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', ValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'DeliverPunishment', ...
            'Timer', S.GUI.PunishAmount,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', 4});
        sma = AddState(sma, 'Name', 'SmallReward', ...
            'Timer', S.GUI.RewardDelayMean,...
            'StateChangeConditions', {'Tup', 'DeliverSmallReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverSmallReward', ...
            'Timer', ValveTime,...
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
        BpodSystem.Data.ITI(currentTrial) = ITI(currentTrial); % Adds the ITI of the current trial to data
        BpodSystem.Data.SideCode(currentTrial) = SideCode(currentTrial); % Adds the SideCode of the current trial to data
        
        %Outcome
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
            BpodSystem.Data.Outcomes(currentTrial) = 1;
        elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Punishment(1))
            BpodSystem.Data.Outcomes(currentTrial) = 0;
            if S.ReTeaching
                TrialTypes(currentTrial+1)=TrialTypes(currentTrial);
            end
        else
            BpodSystem.Data.Outcomes(currentTrial) = -1;
            if S.ReTeaching
                TrialTypes(currentTrial+1)=TrialTypes(currentTrial);
            end
        end
        
        if TrialTypes(currentTrial)==1
            UpdateTotalRewardDisplay(S.GUI.RewardAmountLeft, currentTrial);
        else
            UpdateTotalRewardDisplay(S.GUI.RewardAmountRight, currentTrial);
        end
        UpdateSideOutcomePlot(TrialTypes, BpodSystem.Data);
        SaveBpodSessionData; % Saves the field BpodSystem.Data to the current data file
    end
    HandlePauseCondition; % Checks to see if the protocol is paused. If so, waits until user resumes.
    if BpodSystem.Status.BeingUsed == 0
        return
    end
end

function UpdateSideOutcomePlot(TrialTypes, Data)
global BpodSystem
Outcomes = zeros(1,Data.nTrials);
for x = 1:Data.nTrials
    if ~isnan(Data.RawEvents.Trial{x}.States.Reward(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Punishment(1))
        Outcomes(x) = 0;
    else
        Outcomes(x) = -1;
    end
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
