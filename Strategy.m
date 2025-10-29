% strategy analysis for RE paper

%% --- Phase 1: Data Import and Aggregation ---
% Define the drug condition you are currently running files for
current_drug = 'mec'; 
allData = {};
colsToExtract = {'AnimalID', 'TrialAnalysis_Correct', 'TrialAnalysis_TrialType'};
num_rats = 5; % Adjust as needed

for i = 1:num_rats
    filename = sprintf('%s%d.csv', lower(current_drug), i);
    T = readtable(filename);
    
    subset = T(:, colsToExtract);
    subset.Properties.VariableNames = {'RatID', 'Outcome_Current', 'TrialType_Current'}; 
    subset.Drug = repmat({current_drug}, height(subset), 1);
    
    allData{i} = subset;
end
MasterTable_Drug = vertcat(allData{:}); 
disp(['MasterTable for ', current_drug, ' created.']);

%% --- Phase 1.5: Choice Deduction ---

% Initialize new choice columns (pre-allocating is good practice)
MasterTable_Drug.Choice_Object_Current = cell(height(MasterTable_Drug), 1);
MasterTable_Drug.Choice_Location_Current = cell(height(MasterTable_Drug), 1);

% Apply the deduction function row-by-row
for row = 1:height(MasterTable_Drug)
    tt = MasterTable_Drug.TrialType_Current(row);
    out = MasterTable_Drug.Outcome_Current(row);
    
    % Call the helper function
    [obj, loc] = deduce_choice(tt, out); 
    
    MasterTable_Drug.Choice_Object_Current{row} = obj;
    MasterTable_Drug.Choice_Location_Current{row} = loc;
end

disp('Choice deduction complete. Now calculating strategies.');

%% --- Phase 2: Strategy Calculation (Lagging & Filtering) ---

% Convert RatID to a cell array of strings
MasterTable_Drug.RatID = cellstr(string(MasterTable_Drug.RatID));

% Sort data by RatID (critical for correct lagging)
MasterTable_Drug = sortrows(MasterTable_Drug, 'RatID');

% Create lagged variables (data from the *next* trial)
MasterTable_Drug.Outcome_Next = [MasterTable_Drug.Outcome_Current(2:end); NaN];
MasterTable_Drug.Choice_Object_Next = [MasterTable_Drug.Choice_Object_Current(2:end); {'N/A'}];
MasterTable_Drug.Choice_Location_Next = [MasterTable_Drug.Choice_Location_Current(2:end); {'N/A'}];

% Create a lagged RatID variable to identify session breaks
MasterTable_Drug.RatID_Next = [MasterTable_Drug.RatID(2:end); {'N/A'}];

% Filter out the last trial of each sequence (where the RatID changes)
validRows = strcmp(MasterTable_Drug.RatID, MasterTable_Drug.RatID_Next);
MasterTable_Drug(~validRows, :) = [];

% 1. Define Win-Stay (WS) and Lose-Shift (LS) Flags (Based on Outcome)
MasterTable_Drug.is_Win = MasterTable_Drug.Outcome_Current == 1;
MasterTable_Drug.is_Lose = MasterTable_Drug.Outcome_Current == 0;

% 2. Object Strategy Flags
MasterTable_Drug.is_Stay_Object = strcmp(MasterTable_Drug.Choice_Object_Current, MasterTable_Drug.Choice_Object_Next);
MasterTable_Drug.is_Shift_Object = ~MasterTable_Drug.is_Stay_Object; 

MasterTable_Drug.is_WS_Object = MasterTable_Drug.is_Win & MasterTable_Drug.is_Stay_Object;
MasterTable_Drug.is_LS_Object = MasterTable_Drug.is_Lose & MasterTable_Drug.is_Shift_Object;

% 3. Location Strategy Flags
MasterTable_Drug.is_Stay_Location = strcmp(MasterTable_Drug.Choice_Location_Current, MasterTable_Drug.Choice_Location_Next);
MasterTable_Drug.is_Shift_Location = ~MasterTable_Drug.is_Stay_Location; 

MasterTable_Drug.is_WS_Location = MasterTable_Drug.is_Win & MasterTable_Drug.is_Stay_Location;
MasterTable_Drug.is_LS_Location = MasterTable_Drug.is_Lose & MasterTable_Drug.is_Shift_Location;


%% --- Phase 3: Aggregate and Calculate Proportions per Rat ---

% Aggregate the counts of actual vs. potential strategies per Rat
strategy_summary = groupsummary(MasterTable_Drug, 'RatID', 'sum', ...
    {'is_WS_Object', 'is_LS_Object', 'is_WS_Location', 'is_LS_Location', 'is_Win', 'is_Lose'});

% Rename columns
strategy_summary.Properties.VariableNames = {'RatID', 'GroupCount', ...
    'Actual_WS_Obj', 'Actual_LS_Obj', 'Actual_WS_Loc', 'Actual_LS_Loc', 'Potential_WS', 'Potential_LS'};

% Calculate the final proportions
strategy_summary.Prop_WS_Object = strategy_summary.Actual_WS_Obj ./ strategy_summary.Potential_WS;
strategy_summary.Prop_LS_Object = strategy_summary.Actual_LS_Obj ./ strategy_summary.Potential_LS;
strategy_summary.Prop_WS_Location = strategy_summary.Actual_WS_Loc ./ strategy_summary.Potential_WS;
strategy_summary.Prop_LS_Location = strategy_summary.Actual_LS_Loc ./ strategy_summary.Potential_LS;

% Handle NaNs (0/0 cases)
strategy_summary{:, {'Prop_WS_Object', 'Prop_LS_Object', 'Prop_WS_Location', 'Prop_LS_Location'}}(...
    isnan(strategy_summary{:, {'Prop_WS_Object', 'Prop_LS_Object', 'Prop_WS_Location', 'Prop_LS_Location'}})) = 0;

% --- Display and Save Results ---
final_results = strategy_summary(:, {'RatID', 'Prop_WS_Object', 'Prop_LS_Object', 'Prop_WS_Location', 'Prop_LS_Location'});
disp(['--- Strategy Proportions per Rat for ', current_drug, ' ---']);
disp(final_results);

writetable(final_results, ['Strategy_Summary_', current_drug, '.csv']);



%% --- Phase 4: Data Aggregation ---

% 1. Import all four summary tables
T_Sal = readtable('Strategy_Summary_saline.csv');
T_Mus = readtable('Strategy_Summary_muscimol.csv');
T_Nic = readtable('Strategy_Summary_nicotine.csv');
T_Mec = readtable('Strategy_Summary_mec.csv');

% 2. Add the Drug Condition column to each table
T_Sal.Drug = repmat({'Saline'}, height(T_Sal), 1);
T_Mus.Drug = repmat({'Muscimol'}, height(T_Mus), 1);
T_Nic.Drug = repmat({'Nicotine'}, height(T_Nic), 1);
T_Mec.Drug = repmat({'Mecamylamine'}, height(T_Mec), 1);

% Clean up unnecessary columns from the summary (only keep RatID, Drug, and the four Prop_ columns)
colsToKeep = {'RatID', 'Drug', 'Prop_WS_Object', 'Prop_LS_Object', 'Prop_WS_Location', 'Prop_LS_Location'};
T_Sal = T_Sal(:, colsToKeep);
T_Mus = T_Mus(:, colsToKeep);
T_Nic = T_Nic(:, colsToKeep);
T_Mec = T_Mec(:, colsToKeep);

% 3. Concatenate all tables vertically into the Master Table
MasterStrategyTable = vertcat(T_Sal, T_Mus, T_Nic, T_Mec);

% 4. Format grouping variables for LME
MasterStrategyTable.Drug = categorical(MasterStrategyTable.Drug);
% RatID must be treated as categorical for the random intercept
MasterStrategyTable.RatID = categorical(MasterStrategyTable.RatID); 

disp(['Master Strategy Table created with ', num2str(height(MasterStrategyTable)), ' total rows.']);
disp('---');


%% --- Phase 5: LME Statistical Analysis ---

% The model formula: Strategy Proportion ~ Drug + (1|RatID)

% Model 1: Prop_WS_Object (Object Win-Stay)
disp('LME Model 1: Analyzing Object Win-Stay (Prop_WS_Object)...');
lme_WSO = fitlme(MasterStrategyTable, 'Prop_WS_Object ~ Drug + (1|RatID)');

disp('Fixed Effect Coefficients:');
disp(lme_WSO.Coefficients); % Using .Coefficients for compatibility

anova_WSO = anova(lme_WSO);
disp('ANOVA for Drug Effect:');
disp(anova_WSO);

% Post-Hoc Test if Drug effect is significant (p < 0.05)
if anova_WSO.pValue(strcmp(anova_WSO.Term, 'Drug')) < 0.05
    disp('*** SIGNIFICANT DRUG EFFECT: Running Post-Hoc Comparisons (Tukey-Kramer) ***');
    multcompare(lme_WSO, 'Drug', 'ComparisonType', 'tukey-kramer');
end
disp('----------------------------------------------------');


% Model 2: Prop_LS_Object (Object Lose-Shift)
disp('LME Model 2: Analyzing Object Lose-Shift (Prop_LS_Object)...');
lme_LSO = fitlme(MasterStrategyTable, 'Prop_LS_Object ~ Drug + (1|RatID)');

disp('Fixed Effect Coefficients:');
disp(lme_LSO.Coefficients);

anova_LSO = anova(lme_LSO);
disp('ANOVA for Drug Effect:');
disp(anova_LSO);

% Post-Hoc Test if Drug effect is significant (p < 0.05)
if anova_LSO.pValue(strcmp(anova_LSO.Term, 'Drug')) < 0.05
    disp('*** SIGNIFICANT DRUG EFFECT: Running Post-Hoc Comparisons (Tukey-Kramer) ***');
    multcompare(lme_LSO, 'Drug', 'ComparisonType', 'tukey-kramer');
end
disp('----------------------------------------------------');


% Model 3: Prop_WS_Location (Location Win-Stay)
disp('LME Model 3: Analyzing Location Win-Stay (Prop_WS_Location)...');
lme_WSL = fitlme(MasterStrategyTable, 'Prop_WS_Location ~ Drug + (1|RatID)');

disp('Fixed Effect Coefficients:');
disp(lme_WSL.Coefficients);

anova_WSL = anova(lme_WSL);
disp('ANOVA for Drug Effect:');
disp(anova_WSL);

% Post-Hoc Test if Drug effect is significant (p < 0.05)
%if anova_WSL.pValue(strcmp(anova_WSL.Term, 'Drug')) < 0.05
%    disp('*** SIGNIFICANT DRUG EFFECT: Running Post-Hoc Comparisons (Tukey-Kramer) ***');
%    multcompare(lme_WSL, 'Drug', 'ComparisonType', 'tukey-kramer');
%end
%disp('----------------------------------------------------');


% Model 4: Prop_LS_Location (Location Lose-Shift)
disp('LME Model 4: Analyzing Location Lose-Shift (Prop_LS_Location)...');
lme_LSL = fitlme(MasterStrategyTable, 'Prop_LS_Location ~ Drug + (1|RatID)');

disp('Fixed Effect Coefficients:');
disp(lme_LSL.Coefficients);

anova_LSL = anova(lme_LSL);
disp('ANOVA for Drug Effect:');
disp(anova_LSL);

% Post-Hoc Test if Drug effect is significant (p < 0.05)
if anova_LSL.pValue(strcmp(anova_LSL.Term, 'Drug')) < 0.05
    disp('*** SIGNIFICANT DRUG EFFECT: Running Post-Hoc Comparisons (Tukey-Kramer) ***');
    multcompare(lme_LSL, 'Drug', 'ComparisonType', 'tukey-kramer');
end
disp('----------------------------------------------------');