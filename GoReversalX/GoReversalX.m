function GoReversalX
%
% SETUP
% > Connect the water valve in the box to Bpod Port#1.
% > Connect the air valve in the box to Bpod Port#2.
% > Lick: Bpod Port#3.
% > Xiong Xiao,04/08/2017, CSHL (Bo Li lab)
% > xiaoxiong2n@gmail.com

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmount = 5; % ul
    S.GUI.PunishAmount = 0.2; % s (air puff)
    S.GUI.PreGoTrialNum = 20;
    
    S.GUI.ResponseTimeGo = 1; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.ResponseTimeNoGo = 1; % How long until the mouse must make a choice, or forefeit the trial
    
    S.GUI.TrainingLevel = 3; % Configurable training level
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'Habituation', 'Shaping', 'Task_Normal', 'Task_Reversal', 'Task_Extinction'};
    
    S.GUI.PunishDelay = 1;
    S.GUI.RewardDelay = 1;
    
    S.CueDelay = 1.0; % the time delay from cue onset to response
    S.ITI = 6;
    S.ITI_min=4; S.ITI_max=9;
    S.SoundDuration = 1.0;
    
    S.ReTeaching = 0;
    S.BaselineNoLick = 0;
    
    S.Laser = 0;
    S.LaserDuration = 2; % the duration of laser stimulation
    S.LaserDelayFromTrialOnset = 2; % the onset delay of laser stimulation from trial onset
    
end

if S.GUI.TrainingLevel==2
   S.GUI.ResponseTimeGo = 2; % How long until the mouse must make a choice, or forefeit the trial
   S.GUI.ResponseTimeNoGo = 2; % How long until the mouse must make a choice, or forefeit the trial
   S.GUI.PunishDelay = 0.5;
   S.GUI.RewardDelay = 0.5; 
end

if S.BaselineNoLick && S.Laser
    error('The wrong setting: cannot set the BaselineNoLick during laser stimulation');
elseif S.Laser && S.GUI.TrainingLevel<3
    error('The wrong setting: laser and TrainingLevel');
end

LickPort = 'Port3In';
RewardValveState = 1;
PunishValveState = 2;

% 1: Tone A, go; Tone B, no-go (for normal training)
% 2: Tone A, no-go; Tone B, go (for reversal training)
RuleCode = 1;
if S.GUI.TrainingLevel==4
    RuleCode = 2;
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');

%% Define trials
MaxTrials = 1000;
LaserTrial = zeros(1,MaxTrials);
if S.GUI.TrainingLevel<3
    TrialTypes = ones(1,MaxTrials);
elseif S.GUI.TrainingLevel>=3
    % TrialTypes = ceil(rand(1,MaxTrials)*2)-1;
    TrialTypes = ones(1,MaxTrials);
    seq_type = [1,1,1,1,1,0,0,0,0,0,1,1,1,1,1,0,0,0,0,0];
    for ii=(S.GUI.PreGoTrialNum+1):length(seq_type):MaxTrials
        TrialTypes(ii:ii+length(seq_type)-1) = seq_type(randperm(length(seq_type)));
    end
    
    
    if S.Laser
        seq_type = [1,0,0,0,0];
        for ii=(S.GUI.PreGoTrialNum+1):length(seq_type):MaxTrials
            LaserTrial(ii:ii+length(seq_type)-1) = seq_type(randperm(length(seq_type)));
        end
    end
        
end

PunishDelay = repmat(S.GUI.PunishDelay,1,MaxTrials);
RewardDelay = repmat(S.GUI.RewardDelay,1,MaxTrials);

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
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [100 200 1200 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
% BpodSystem.ProtocolFigures.LickPlotFig = figure('Position', [600 200 600 200],'name','Licking','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
GoNoGoOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',TrialTypes);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySoundX';

SF = 192000; % Sound card sampling rate
SinWaveFreq1 = 3000;
sounddata1 = GenerateSineWave(SF, SinWaveFreq1, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
SinWaveFreq2 = 10000;
sounddata2 = GenerateSineWave(SF, SinWaveFreq2, S.SoundDuration); % Sampling freq (hz), Sine frequency (hz), duration (s)
% sounddata3 = (rand(1,SF*S.SoundDuration+1)*2) - 1;
% WidthOfFrequencies=1.5; NumberOfFrequencies=7; MeanSoundFreq4 = 6000; SoundRamping=0.2;
% sounddata4 = SoundGenerator(SF, MeanSoundFreq4, WidthOfFrequencies, NumberOfFrequencies, S.SoundDuration, SoundRamping);

% Program sound server
PsychToolboxSoundServer('init')
PsychToolboxSoundServer('Load', 1, sounddata1);
PsychToolboxSoundServer('Load', 2, sounddata2);
% PsychToolboxSoundServer('Load', 3, sounddata3);
% PsychToolboxSoundServer('Load', 4, sounddata4);

%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1]);
    RewardValveTime = R; % Update reward amounts
    
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % go trial
            if RuleCode==1
                soundID = 1;
            else
                soundID = 2;
            end
            LickOutcome = 'Reward';
            ResponseTime = S.GUI.ResponseTimeGo;
            Tup_Action = 'ITI';
            OutcomeDelay = S.GUI.RewardDelay;
        case 0 % no-go trial
            if RuleCode==1
                soundID = 2;
            else
                soundID = 1;
            end
            LickOutcome = 'Punishment';
            ResponseTime = S.GUI.ResponseTimeNoGo;
            Tup_Action = 'ITI';
            OutcomeDelay = S.GUI.PunishDelay;
    end
    
    if LaserTrial(currentTrial)
        laser_arg = {'GlobalTimerTrig', 2};
    else
        laser_arg = {};
    end
    
    sma = NewStateMatrix(); % Assemble state matrix
    
    if S.GUI.TrainingLevel==1 % 'Habituation'
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,... % time before trial start
            'StateChangeConditions', {'Tup', 'ResponseW'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResponseW', ...
            'Timer', 10,... % reponse time window
            'StateChangeConditions', {LickPort, 'Reward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', 0,... % reward delay
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', RewardValveTime,... % reward amount
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', RewardValveState}); % 'SoftCode', soundID
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    elseif S.GUI.TrainingLevel==2 % 'Shaping'
        
        if S.BaselineNoLick
            sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 2,...
                'StateChangeConditions', {'Tup', 'StimulusDeliver',LickPort,'TrialStart'},...
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 2,...
                'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
                'OutputActions', {});
        end
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
            'StateChangeConditions', {LickPort, LickOutcome, 'Tup', Tup_Action},...
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
            'OutputActions', {'ValveState', RewardValveState});
        sma = AddState(sma, 'Name', 'DeliverPunishment', ...
            'Timer', S.GUI.PunishAmount,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', PunishValveState});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', ITI(currentTrial),...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    elseif S.GUI.TrainingLevel>2 && S.GUI.TrainingLevel<5 % 'Shaping', 'Task_Normal', 'Task_Reversal'
        
        sma = SetGlobalTimer(sma, 'TimerID', 1, 'Duration', OutcomeDelay, 'OnsetDelay', S.CueDelay);
        sma = SetGlobalTimer(sma, 'TimerID', 2, 'Duration', S.LaserDuration, 'OnsetDelay', S.LaserDelayFromTrialOnset, 'Channel', 'BNC1');
        
        if S.BaselineNoLick
            sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 2,...
                'StateChangeConditions', {'Tup', 'StimulusDeliver',LickPort,'TrialStart'},...
                'OutputActions', {});
        else
            sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 2,...
                'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
                'OutputActions', laser_arg);
        end
        sma = AddState(sma, 'Name', 'StimulusDeliver', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'CueDelay'},...
            'OutputActions', {'SoftCode', soundID,'GlobalTimerTrig', 1});
        sma = AddState(sma, 'Name', 'CueDelay', ...
            'Timer', S.CueDelay,...
            'StateChangeConditions', {'Tup', 'ResponseW'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ResponseW', ...
            'Timer', ResponseTime,...
            'StateChangeConditions', {LickPort, LickOutcome, 'Tup', Tup_Action},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', RewardDelay(currentTrial),...
            'StateChangeConditions', {'Tup', 'DeliverReward','GlobalTimer1_End','DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'Punishment', ...
            'Timer', PunishDelay(currentTrial),...
            'StateChangeConditions', {'Tup', 'DeliverPunishment','GlobalTimer1_End','DeliverPunishment'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', RewardValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', RewardValveState});
        sma = AddState(sma, 'Name', 'DeliverPunishment', ...
            'Timer', S.GUI.PunishAmount,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', PunishValveState});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', ITI(currentTrial),...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    elseif S.GUI.TrainingLevel==5 % 'Task_Extinction'
        
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'StimulusDeliver'},...
            'OutputActions', {});
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
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {});
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
        
        if S.ReTeaching==1 && S.GUI.TrainingLevel>=3 % full task
            if BpodSystem.Data.Outcomes(currentTrial) == 0
                TrialTypes(currentTrial+1)=0;
            elseif BpodSystem.Data.Outcomes(currentTrial) == -1
                TrialTypes(currentTrial+1)=1;
            end
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
