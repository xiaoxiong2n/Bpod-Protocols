%% Probabilistic switching task
function ProbabilisticSwitchingF
% This protocol is for head-fixed probability switching task
% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 4 ports.
% > Connect the left water port in the box to Bpod Port#1.
% > Connect the right water port in the box to Bpod Port#2.
% > Connect the left lick port in the box to Bpod Port#3.
% > Connect the right lick port in the box to Bpod Port#4.
% > Make sure the liquid calibration tables for ports 1 and 2 have
%   calibration curves with several points surrounding 3ul.
% > Xiong Xiao,04/08/2017, CSHL (Bo Li lab)
% > xiaoxiong2n@gmail.com

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmount = 5; %ul
    S.GUI.RewardProbability = 0.75; % 0.75
    S.GUI.ResponseTime = 15; % How long until the mouse must make a choice, or forefeit the trial
    S.GUI.PunishDelay = 0;
    S.GUI.RewardLengthMin = 7;
    S.GUI.RewardLengthMax = 16;
    S.GUI.ITI = 4;
    
    S.GUI.TrainingLevel = 1; % Configurable reward condition schemes
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'Habituation', 'Task_cued','Task_full'};
    
    S.GUIPanels.Task = {'TrainingLevel', 'RewardAmount', 'RewardProbability','RewardLengthMin','RewardLengthMax'}; % GUIPanels organize the parameters into groups.
    S.GUIPanels.Time = {'ResponseTime','PunishDelay','ITI'};
    
    S.StartSoundDuration = 0.5;
    S.RewardDelay = 0.1;
    S.LightBrightness = 64; % full = 255
end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');

%% Define trials
MaxTrials = 1000;
TrialTypeInitial = ceil(rand(1)*2);

% TrialTypes = nan(1,MaxTrials);
TrialTypes = repmat(TrialTypeInitial,1,MaxTrials);
TrialRewarded = nan(1,MaxTrials);
TrialBlockNum = randi([S.GUI.RewardLengthMin,S.GUI.RewardLengthMax],MaxTrials);

% Set soft code handler to trigger sounds
BpodSystem.SoftCodeHandlerFunction = 'SoftCodeHandler_PlaySound';
% define sounds
SF = 192000; % Sound card sampling rate
StartSound = (rand(1,SF*S.StartSoundDuration)*2) - 1; % white noise

% Program sound server
PsychToolboxSoundServer('init');
PsychToolboxSoundServer('Load', 1, StartSound);

BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.
BpodSystem.Data.TrialRewarded = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);

%% Main trial loop
RewardN = 0;
BlockN = 1;
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 2]); LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
        
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % left port is rewarded
            if rand<S.GUI.RewardProbability
                LeftActionState = 'Reward';
                TrialRewarded(currentTrial)=1;
            else
                LeftActionState = 'Unrewarded';
                TrialRewarded(currentTrial)=0;
            end
            RightActionState = 'Wrong';
            ValveTime = LeftValveTime;
            ValveState = 1;
            StimulusOutput = {'PWM1', S.LightBrightness};
        case 2 % right port is rewarded
            if rand<S.GUI.RewardProbability
                RightActionState = 'Reward';
                TrialRewarded(currentTrial)=1;
            else
                RightActionState = 'Unrewarded';
                TrialRewarded(currentTrial)=0;
            end
            LeftActionState = 'Wrong';
            ValveTime = RightValveTime;
            ValveState = 2;
            StimulusOutput = {'PWM2', S.LightBrightness};
    end
    
    if S.GUI.TrainingLevel==1
        switch TrialTypes(currentTrial)
            case 1 % left port is rewarded
                ResponseArgument = {'Port3In','Reward'};
            case 2 % right port is rewarded
                ResponseArgument = {'Port4In','Reward'};
        end
    end
    
    if S.GUI.TrainingLevel==3
        StimulusOutput = {'PWM1', S.LightBrightness,'PWM2', S.LightBrightness};
    end    
    
    sma = NewStateMatrix(); % Assemble state matrix
    if S.GUI.TrainingLevel==1 % Habituation
        sma = AddState(sma, 'Name', 'Base', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'TrialStart'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'StartSoundDelay'},...
            'OutputActions', {'SoftCode', 1});
        sma = AddState(sma, 'Name', 'StartSoundDelay', ...
            'Timer', S.StartSoundDuration,...
            'StateChangeConditions', {'Tup', 'CueDeliver'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'CueDeliver', ...
            'Timer', S.GUI.ResponseTime,...
            'StateChangeConditions', [ResponseArgument, {'Tup', 'ITI'}],...
            'OutputActions', StimulusOutput);
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.RewardDelay,...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', ValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'Unrewarded', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions',{});
        sma = AddState(sma, 'Name', 'Wrong', ...
            'Timer', S.GUI.PunishDelay,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', S.GUI.ITI,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
        
    else % Task
        sma = AddState(sma, 'Name', 'Base', ...
            'Timer', 2,...
            'StateChangeConditions', {'Tup', 'TrialStart'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'TrialStart', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'StartSoundDelay'},...
            'OutputActions', {'SoftCode', 1});
        sma = AddState(sma, 'Name', 'StartSoundDelay', ...
            'Timer', S.StartSoundDuration,...
            'StateChangeConditions', {'Tup', 'CueDeliver'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'CueDeliver', ...
            'Timer', S.GUI.ResponseTime,...
            'StateChangeConditions', {'Port3In', LeftActionState, 'Port4In', RightActionState, 'Tup', 'ITI'},...
            'OutputActions', StimulusOutput);
        sma = AddState(sma, 'Name', 'Reward', ...
            'Timer', S.RewardDelay,...
            'StateChangeConditions', {'Tup', 'DeliverReward'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'DeliverReward', ...
            'Timer', ValveTime,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {'ValveState', ValveState});
        sma = AddState(sma, 'Name', 'Unrewarded', ...
            'Timer', 0,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions',{});
        sma = AddState(sma, 'Name', 'Wrong', ...
            'Timer', S.GUI.PunishDelay,...
            'StateChangeConditions', {'Tup', 'ITI'},...
            'OutputActions', {});
        sma = AddState(sma, 'Name', 'ITI', ...
            'Timer', S.GUI.ITI,...
            'StateChangeConditions', {'Tup', 'exit'},...
            'OutputActions', {});
    end
    
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        BpodSystem.Data.TrialRewarded(currentTrial) = TrialRewarded(currentTrial); % Adds the trial type of the current trial to data
        
        %Outcome
        if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
            BpodSystem.Data.Outcomes(currentTrial) = 1;
            RewardN = RewardN+1;
            % aux0 = randi(S.GUI.RewardLengthMax-S.GUI.RewardLengthMin+1)+S.GUI.RewardLengthMin-1;
            aux0 = TrialBlockNum(BlockN);
            if RewardN>=aux0
                TrialTypeInitial = 3-TrialTypeInitial;
                TrialTypes(currentTrial+1:end) = TrialTypeInitial;
                RewardN = 0;
                BlockN = BlockN+1;
            end
        elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Wrong(1))
            BpodSystem.Data.Outcomes(currentTrial) = 0;
        elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Unrewarded(1))
            BpodSystem.Data.Outcomes(currentTrial) = 2;
        else
            BpodSystem.Data.Outcomes(currentTrial) = 3;
        end
        
        UpdateTotalRewardDisplay(S.GUI.RewardAmount, currentTrial);
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
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Wrong(1))
        Outcomes(x) = 0;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Unrewarded(1))
        Outcomes(x) = 2;
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
