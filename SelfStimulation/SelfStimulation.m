%% Probabilistic switching task
function SelfStimulation

% SETUP
% You will need:
% - A Bpod MouseBox (or equivalent) configured with 3 ports.
% > Connect the left port in the box to Bpod Port#1.
% > Connect the center port in the box to Bpod Port#2.
% > Connect the right port in the box to Bpod Port#3.
% > Make sure the liquid calibration tables for ports 1 and 3 have
%   calibration curves with several points surrounding 10ul.
% > Xiong Xiao,03/05/2017, CSHL (Bo Li lab)
% > xiaoxiong2n@gmail.com

global BpodSystem

%% Define parameters
S = BpodSystem.ProtocolSettings; % Load settings chosen in launch manager into current workspace as a struct called S
if isempty(fieldnames(S))  % If settings file was an empty struct, populate struct with default settings
    
    S.GUI.RewardAmount = 10; %ul
    S.GUI.LaserSide = 1; % 1, left; 2, right
    S.GUI.LaserDuration = 2;
        
    S.GUI.TrainingLevel = 2;
    S.GUIMeta.TrainingLevel.Style = 'popupmenu'; % the GUIMeta field is used by the ParameterGUI plugin to customize UI objects.
    S.GUIMeta.TrainingLevel.String = {'Habituation', 'SelfStimulation'};

end

% Initialize parameter GUI plugin
BpodParameterGUI('init', S);
TotalRewardDisplay('init');

%% Define trials
MaxTrials = 1000;
switch S.GUI.LaserSide
    case 1
        TrialTypes = ones(1,MaxTrials);
    case 2
        TrialTypes = 2*ones(1,MaxTrials);
end
BpodSystem.Data.TrialTypes = []; % The trial type of each trial completed will be added here.

%% Initialize plots
BpodSystem.ProtocolFigures.SideOutcomePlotFig = figure('Position', [200 200 1000 300],'name','Outcome plot','numbertitle','off', 'MenuBar', 'none', 'Resize', 'off');
BpodSystem.GUIHandles.SideOutcomePlot = axes('Position', [.075 .3 .89 .6]);
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'init',2-TrialTypes);

%% Main trial loop
for currentTrial = 1:MaxTrials
    
    S = BpodParameterGUI('sync', S); % Sync parameters with BpodParameterGUI plugin
    R = GetValveTimes(S.GUI.RewardAmount, [1 3]);
    LeftValveTime = R(1); RightValveTime = R(2); % Update reward amounts
        
    switch TrialTypes(currentTrial) % Determine trial-specific state matrix fields
        case 1 % left port is rewarded
            ValveTime = LeftValveTime;
            ValveState = 1;
            resp_arg = 'Port1In';
        case 2 % right port is rewarded
            ValveTime = RightValveTime;
            ValveState = 4;
            resp_arg = 'Port3In';
    end
    
    if S.GUI.LaserSide==1
        laser_arg = {'Port1In','Laser','Port3In','ShamLaser','Tup','exit'};
    elseif S.GUI.LaserSide==2
        laser_arg = {'Port1In','ShamLaser','Port3In','Laser','Tup','exit'};
    end

    sma = NewStateMatrix(); % Assemble state matrix
    switch S.GUI.TrainingLevel
        case 1 % Habituation
            sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 0.5,...
                'StateChangeConditions', {'Tup', 'WaitForResponse'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForResponse', ...
                'Timer', 30,...
                'StateChangeConditions', {resp_arg, 'Reward', 'Tup', 'exit'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'Reward', ...
                'Timer', ValveTime,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {'ValveState', ValveState});
            sma = AddState(sma, 'Name', 'Drinking', ...
                'Timer', 0.5,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions', {});
             sma = AddState(sma, 'Name', 'Laser', ...
                'Timer', S.GUI.LaserDuration,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {'BNC1', 1});
            sma = AddState(sma, 'Name', 'ShamLaser', ...
                'Timer', S.GUI.LaserDuration,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {});
            
            case 2 % Self-Stimulation
                
                sma = AddState(sma, 'Name', 'TrialStart', ...
                'Timer', 0,...
                'StateChangeConditions', {'Tup', 'WaitForResponse'},...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'WaitForResponse', ...
                'Timer', 30,...
                'StateChangeConditions', laser_arg,...
                'OutputActions', {});
            sma = AddState(sma, 'Name', 'Reward', ...
                'Timer', ValveTime,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {'ValveState', ValveState});
            sma = AddState(sma, 'Name', 'Drinking', ...
                'Timer', 0,...
                'StateChangeConditions', {'Tup', 'exit'},...
                'OutputActions', {});  
            sma = AddState(sma, 'Name', 'Laser', ...
                'Timer', S.GUI.LaserDuration,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {'BNC1', 1});
            sma = AddState(sma, 'Name', 'ShamLaser', ...
                'Timer', S.GUI.LaserDuration,...
                'StateChangeConditions', {'Tup', 'Drinking'},...
                'OutputActions', {});
            
    end
    SendStateMatrix(sma);
    RawEvents = RunStateMatrix;
    
    if ~isempty(fieldnames(RawEvents)) % If trial data was returned
        BpodSystem.Data = AddTrialEvents(BpodSystem.Data,RawEvents); % Computes trial events from raw data
        BpodSystem.Data.TrialSettings(currentTrial) = S; % Adds the settings used for the current trial to the Data struct (to be saved after the trial ends)
        BpodSystem.Data.TrialTypes(currentTrial) = TrialTypes(currentTrial); % Adds the trial type of the current trial to data
        
       if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Drinking(1))
           BpodSystem.Data.Outcomes(currentTrial) = 1;
           if S.GUI.TrainingLevel==1
               TrialTypes(currentTrial+1:end) = 3-TrialTypes(currentTrial);
           end
       elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Laser(1))
           BpodSystem.Data.Outcomes(currentTrial) = 2;
       else
           BpodSystem.Data.Outcomes(currentTrial) = 0;
       end
       
       if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Laser(1))
           TrialTypes(currentTrial) = S.GUI.LaserSide;
       elseif ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.ShamLaser(1))
           TrialTypes(currentTrial) = 3-S.GUI.LaserSide;
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
    if ~isnan(Data.RawEvents.Trial{x}.States.Drinking(1))
        Outcomes(x) = 1;
    elseif ~isnan(Data.RawEvents.Trial{x}.States.Laser(1))
        Outcomes(x) = 2;
    else
        Outcomes(x) = 0;
    end
    
end
SideOutcomePlot(BpodSystem.GUIHandles.SideOutcomePlot,'update',Data.nTrials+1,2-TrialTypes,Outcomes);

function UpdateTotalRewardDisplay(RewardAmount, currentTrial)
% If rewarded based on the state data, update the TotalRewardDisplay
global BpodSystem
if ~isnan(BpodSystem.Data.RawEvents.Trial{currentTrial}.States.Reward(1))
    TotalRewardDisplay('add', RewardAmount);
end
