 classdef app1 < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                        matlab.ui.Figure
        CurrentlistofmeasuresListBox    matlab.ui.control.ListBox
        CurrentlistofmeasuresListBoxLabel  matlab.ui.control.Label
        DeleteMeasuresButton            matlab.ui.control.Button
        CurrentlistoftimeseriesListBox  matlab.ui.control.ListBox
        CurrentlistoftimeseriesListBoxLabel  matlab.ui.control.Label
        ViewmeasuresButton              matlab.ui.control.Button
        savemeasuresButton              matlab.ui.control.Button
        SelectrunmeasuresButton         matlab.ui.control.Button
        HelpButton                      matlab.ui.control.Button
        ExitButton                      matlab.ui.control.Button
        DeleteButton                    matlab.ui.control.Button
        SortbynameButton                matlab.ui.control.Button
        LoadtimeseriesButton            matlab.ui.control.Button
        PreviewTimeSeriesButton         matlab.ui.control.Button
        ShowMatricesButton              matlab.ui.control.Button
    end

    properties (Access = public)
        LoadedTimeSeriesData  % Property to store loaded time series data
        MeasureResults        % Store results from the second app
        MIBins = 10          % Default number of bins for MI calculation
        MILags = 1           % Default number of lags for MI calculation
        GCOrder = 2          % Default model order for Granger Causality
        TimeSeriesFiles = {}  % Store names of loaded time series files
        AllTimeSeriesData = {} % Store all loaded time series data sets
        WindowCounter = 0     % Counter for cascading window positions
    end
    
   

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: LoadtimeseriesButton
        function LoadtimeseriesButtonPushed(app, event)
            % Open file selection dialog
            [files, path] = uigetfile('*.txt', 'Select Time Series Text Files', 'MultiSelect', 'on');
            
            % Check if the user canceled the file selection
            if isequal(files, 0)
                disp('User canceled file selection.');
                return;
            end

            % Convert to cell array if only one file is selected
            if ~iscell(files)
                files = {files};
            end
            
            % Initialize if first time loading
            if isempty(app.AllTimeSeriesData)
                app.AllTimeSeriesData = {};
                app.TimeSeriesFiles = {};
            end
            
            nLoadedOK = 0;
            for i = 1:length(files)
            % Construct the full file path
                fullFilePath = fullfile(path, files{i});
        
            try
                    % Try to read as numeric matrix first (most flexible approach)
                    try
                        % Read as numeric matrix
                        dataMatrix = readmatrix(fullFilePath, 'Delimiter', {'\t',' ',',',';'}, ...
                            'ConsecutiveDelimitersRule', 'join', 'LeadingDelimitersRule', 'ignore', ...
                            'TrailingDelimitersRule', 'ignore', 'EmptyLineRule', 'skip');
                        
                        % Remove only leading all-NaN rows (e.g. a text header)
                        % and trailing all-NaN rows (e.g. empty lines at the end).
                        % All-NaN rows in the middle are kept, so that the file
                        % is rejected below instead of silently breaking the
                        % temporal continuity of the series.
                        validRows = find(~all(isnan(dataMatrix), 2));
                        if ~isempty(validRows)
                            dataMatrix = dataMatrix(validRows(1):validRows(end), :);
                        end
                        
                        % Remove any columns that are all NaN
                        dataMatrix = dataMatrix(:, ~all(isnan(dataMatrix), 1));
                        
                        if isempty(dataMatrix)
                            error('No valid numeric data found');
                        end
                        
                        % Non-finite values are NOT replaced here; the file is
                        % rejected further below with a message to the user.
                        
                        % Determine if first column looks like time indices
                        hasTimeColumn = false;
                        if size(dataMatrix, 2) > 1
                            firstCol = dataMatrix(:, 1);
                            % Check if first column is sequential integers starting from 1 or 0
                            if all(firstCol == round(firstCol)) && ... % All integers
                               (all(diff(firstCol) == 1) || ... % Sequential with step 1
                                (firstCol(1) == 0 && all(diff(firstCol) == 1)) || ... % Starting from 0
                                (firstCol(1) == 1 && all(diff(firstCol) == 1))) % Starting from 1
                                hasTimeColumn = true;
                            end
                        end
                        
                        % Try to read a textual header (variable names) from
                        % the first line of the file. readmatrix discards it,
                        % so we recover it here to use real variable names.
                        headerNames = {};
                        fidH = fopen(fullFilePath, 'rt');
                        if fidH ~= -1
                            rawHeader = fgetl(fidH);
                            fclose(fidH);
                            if ischar(rawHeader) && ~isempty(strtrim(rawHeader))
                                tokens = regexp(strtrim(rawHeader), '[\t ,;]+', 'split');
                                tokens = tokens(~cellfun(@isempty, tokens));
                                % It is a header only if a token is non-numeric
                                if ~isempty(tokens) && any(isnan(str2double(tokens)))
                                    headerNames = tokens;
                                end
                            end
                        end
                        
                        % Create appropriate table structure
                        if hasTimeColumn
                            % First column is time, rest are variables
                            timeCol = dataMatrix(:, 1);
                            varData = dataMatrix(:, 2:end);
                            nVars = size(varData, 2);
                            
                            % Create variable names (use header if available)
                            varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                            if numel(headerNames) == nVars + 1
                                varNames = headerNames(2:end); % skip time label
                            elseif numel(headerNames) == nVars
                                varNames = headerNames;        % no time label in header
                            end
                            varNames = matlab.lang.makeValidName(varNames);
                            
                            % Create table with time column
                            timeSeriesData = array2table([timeCol, varData]);
                            timeSeriesData.Properties.VariableNames = [{'Time'}, varNames];
                        else
                            % All columns are variables, create time column
                            nPoints = size(dataMatrix, 1);
                            nVars = size(dataMatrix, 2);
                            timeCol = (1:nPoints)';
                            
                            % Create variable names (use header if available)
                            varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                            if numel(headerNames) == nVars
                                varNames = headerNames;
                            end
                            varNames = matlab.lang.makeValidName(varNames);
                            
                            % Create table with generated time column
                            timeSeriesData = array2table([timeCol, dataMatrix]);
                            timeSeriesData.Properties.VariableNames = [{'Time'}, varNames];
                        end
                        
                    catch ME1
                        % Fallback to original table-based approach
                        opts = detectImportOptions(fullFilePath, 'FileType', 'text');
                        opts.Delimiter = {'\t',' ', ',', ';'};
                        if isprop(opts, 'ConsecutiveDelimitersRule')
                            opts.ConsecutiveDelimitersRule = 'join';
                        end
                        opts.VariableNamingRule = 'preserve';
                        
                        % Force numeric data type for all columns
                        for j = 1:length(opts.VariableTypes)
                            opts.VariableTypes{j} = 'double';
                        end
                        
                        timeSeriesData = readtable(fullFilePath, opts);
                        
                        % Convert any remaining cell arrays to numeric
                        for j = 1:width(timeSeriesData)
                            if iscell(timeSeriesData{:,j})
                                timeSeriesData{:,j} = cellfun(@(x) str2double(x), timeSeriesData{:,j}, 'UniformOutput', false);
                                timeSeriesData{:,j} = cell2mat(timeSeriesData{:,j});
                            end
                        end
                        
                        % If no time column detected, add one (preserve the
                        % real variable names read from the file header)
                        if width(timeSeriesData) >= 1
                            dataArray = table2array(timeSeriesData);
                            if size(dataArray, 2) > 0
                                nPoints = height(timeSeriesData);
                                timeCol = (1:nPoints)';
                                nVars = width(timeSeriesData);
                                origNames = timeSeriesData.Properties.VariableNames;
                                if numel(origNames) == nVars
                                    varNames = origNames;
                                else
                                    varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                                end
                                varNames = matlab.lang.makeValidName(varNames);
                                timeSeriesData = array2table([timeCol, dataArray]);
                                timeSeriesData.Properties.VariableNames = [{'Time'}, varNames];
                            end
                        end
                    end
                    
                    % Final validation
                    if isempty(timeSeriesData) || height(timeSeriesData) < 3
                        error('Time series must have at least 3 data points');
                    end
                    
                    if width(timeSeriesData) < 2
                        error('Time series must have at least 1 variable (plus time column)');
                    end
                    
                    % Check for minimum 2 variables (needed for causality/correlation measures)
                    numVariables = width(timeSeriesData) - 1; % Exclude time column
                    if numVariables < 2
                        uialert(app.UIFigure, sprintf(['Cannot load time series with only %d variable.\n\n' ...
                            'Causality and correlation measures require at least 2 variables to compute relationships between them.\n\n' ...
                            'Please load a file with 2 or more variables.'], numVariables), ...
                            'Insufficient Variables', 'Icon', 'warning');
                        continue; % Skip this file and continue with next
                    end
                    
                    % Reject any file that still contains NaN/non-finite values.
                    % Causality/correlation measures require complete data, so we
                    % do not silently drop or impute missing values.
                    checkData = table2array(timeSeriesData);
                    if size(checkData, 2) > 1
                        % Exclude the Time column from the missing-value check
                        checkData = checkData(:, 2:end);
                    end
                    if any(~isfinite(checkData(:)))
                        nMissing = sum(~isfinite(checkData(:)));
                        % Report the positions (row = time index, column = variable)
                        [badR, badC] = find(~isfinite(checkData));
                        vNames = timeSeriesData.Properties.VariableNames(2:end);
                        nShow = min(10, numel(badR));
                        posList = strings(nShow, 1);
                        for q = 1:nShow
                            posList(q) = sprintf('  row %d, variable %s', badR(q), vNames{badC(q)});
                        end
                        posStr = strjoin(posList, '\n');
                        if numel(badR) > nShow
                            posStr = sprintf('%s\n  ... and %d more', posStr, numel(badR) - nShow);
                        end
                        uialert(app.UIFigure, sprintf(['Cannot load "%s".\n\n' ...
                            'The time series contains %d missing/invalid value(s) (NaN or Inf) at:\n%s\n\n' ...
                            'Missing values are not removed or filled in automatically, because this ' ...
                            'would change the temporal structure of the series. Please replace them ' ...
                            '(e.g. by interpolation) and load the file again.'], files{i}, nMissing, posStr), ...
                            'Missing Values Detected', 'Icon', 'error');
                        continue; % Skip this file and continue with next
                    end

                    % Add to the list of all time series data
                    app.AllTimeSeriesData{end+1} = timeSeriesData;
                    app.TimeSeriesFiles{end+1} = files{i};
                    nLoadedOK = nLoadedOK + 1;
                    
                    % Save the most recently loaded data for immediate use
                app.LoadedTimeSeriesData = timeSeriesData;
                    
                    % Clear previous measures since they're for old data
                    app.MeasureResults = [];
                    % Update measures list display
                    app.updateCurrentMeasuresList();
        
                    % Notify success for this file
                    disp(['File ' files{i} ' loaded successfully!']);
                    disp(['Number of time points: ' num2str(height(timeSeriesData))]);
                    disp(['Number of variables: ' num2str(width(timeSeriesData)-1)]); % Subtract 1 for time column
                    disp(['Variable names: ' strjoin(timeSeriesData.Properties.VariableNames(2:end), ', ')]);
                    
            catch ME
                    % Handle errors for this file
                    disp(['Error loading file ' files{i} ': ', ME.message]);
                    uialert(app.UIFigure, ['Failed to load ' files{i} '. Error: ' ME.message], 'Error', 'Icon', 'error');
                end
            end
            
            % Update the ListBox with the loaded file names
            app.CurrentlistoftimeseriesListBox.Items = app.TimeSeriesFiles;
            
            % Select the most recently loaded file
            if ~isempty(app.TimeSeriesFiles)
                app.CurrentlistoftimeseriesListBox.Value = app.TimeSeriesFiles{end};
            end
            
            % Notify the user of successful loading
            if nLoadedOK > 0
                uialert(app.UIFigure, [num2str(nLoadedOK) ' of ' num2str(length(files)) ' time series file(s) loaded successfully!'], 'Success', 'Icon', 'success');
            end
            % Ensure main window stays visible and not minimized
            app.bringAppToFront();
        end

        % Button pushed function: savemeasuresButton
        function savemeasuresButtonPushed(app, event)
            try
                % Check if measures data exists
                if isempty(app.MeasureResults) || ...
                   (~isfield(app.MeasureResults, 'MI') && ~isfield(app.MeasureResults, 'TE') && ...
                    ~isfield(app.MeasureResults, 'PTE') && ~isfield(app.MeasureResults, 'CC') && ...
                    ~isfield(app.MeasureResults, 'GC') && ~isfield(app.MeasureResults, 'CGCI'))
                    uialert(app.UIFigure, 'No measures data to save. Please compute measures first.', 'Error', 'Icon', 'error');
                    return;
                end

                % Always save to a folder chosen by the user
                folder = uigetdir('', 'Select Folder to Save Measures');
                if isequal(folder, 0)
                    disp('User canceled folder selection.');
                    return;
                end
                % Use default filename
                filename = 'measures.txt';
                fullFilePath = fullfile(folder, filename);

                fid = fopen(fullFilePath, 'w');
                if fid == -1
                    uialert(app.UIFigure, 'Failed to open the output file for writing.', 'Error', 'Icon', 'error');
                    return;
                end

                % Resolve variable names (exclude Time column if present)
                baseVarNames = {};
                if istable(app.LoadedTimeSeriesData)
                    try
                        baseVarNames = app.LoadedTimeSeriesData.Properties.VariableNames;
                        if ~isempty(baseVarNames) && strcmpi(baseVarNames{1}, 'Time')
                            baseVarNames = baseVarNames(2:end);
                        end
                    catch
                        baseVarNames = {};
                    end
                end

                % Ordered save of all available measures
                fieldsInOrder = {'MI','TE','PTE','GC','CGCI','CC'};
                for k = 1:numel(fieldsInOrder)
                    field = fieldsInOrder{k};
                    if ~isfield(app.MeasureResults, field) || isempty(app.MeasureResults.(field))
                        continue;
                    end
                    % Label and normalization per measure
                    switch field
                        case 'MI'
                            label = 'Mutual Information';
                            normalizeFlag = true;
                        case 'TE'
                            label = 'Transfer Entropy';
                            normalizeFlag = true;
                        case 'PTE'
                            label = 'Partial Transfer Entropy';
                            normalizeFlag = true;
                        case 'GC'
                            label = 'Granger Causality Index';
                            normalizeFlag = true;
                        case 'CGCI'
                            label = 'Conditional Granger Causality Index';
                            normalizeFlag = true;
                        case 'CC'
                            % Provide extra info (lag/alpha/threshold) in title if available
                            lagTxt = '';
                            try
                                if isfield(app.MeasureResults, 'CC_lagUsed') && ~isempty(app.MeasureResults.CC_lagUsed)
                                    lagTxt = sprintf(', lag=%d', app.MeasureResults.CC_lagUsed);
                                end
                            catch, end
                            alphaTxt = '';
                            try
                                if isfield(app.MeasureResults, 'CC_alpha') && ~isempty(app.MeasureResults.CC_alpha)
                                    alphaTxt = sprintf(', alpha=%.3f', app.MeasureResults.CC_alpha);
                                end
                            catch, end
                            thrTxt = '';
                            try
                                if isfield(app.MeasureResults, 'CC_thr') && ~isempty(app.MeasureResults.CC_thr)
                                    thrTxt = sprintf(', rcrit=%.3f', app.MeasureResults.CC_thr);
                                end
                            catch, end
                            label = ['Cross-Correlation' lagTxt alphaTxt thrTxt];
                            normalizeFlag = false; % keep Pearson r as-is
                    end
                    app.writeLabeledMatrixToFile(fid, label, app.MeasureResults.(field), normalizeFlag, baseVarNames);

                    % Extra tables tied to certain measures
                    if strcmp(field, 'GC') && isfield(app.MeasureResults, 'GC_p') && ~isempty(app.MeasureResults.GC_p)
                        app.writeLabeledMatrixToFile(fid, 'Granger Causality p-values (F-test)', app.MeasureResults.GC_p, false, baseVarNames);
                    end
                    if strcmp(field, 'CGCI') && isfield(app.MeasureResults, 'CGCI_p') && ~isempty(app.MeasureResults.CGCI_p)
                        app.writeLabeledMatrixToFile(fid, 'CGCI p-values (F-test)', app.MeasureResults.CGCI_p, false, baseVarNames);
                    end
                    if strcmp(field, 'CC')
                        if isfield(app.MeasureResults, 'CC_p') && ~isempty(app.MeasureResults.CC_p)
                            app.writeLabeledMatrixToFile(fid, 'Cross-Correlation p-values', app.MeasureResults.CC_p, false, baseVarNames);
                        end
                        if isfield(app.MeasureResults, 'CC_sig') && ~isempty(app.MeasureResults.CC_sig)
                            app.writeLabeledMatrixToFile(fid, 'Cross-Correlation significance (0/1)', double(app.MeasureResults.CC_sig), false, baseVarNames);
                        end
                    end
                end

                fclose(fid);
                % Notify the user of success
                disp(['Measures saved successfully to: ', fullFilePath]);
                uialert(app.UIFigure, ['Measures saved successfully to: ', fullFilePath], 'Success', 'Icon', 'success');
                return;
            catch ME
                % Handle errors gracefully
                disp(['Error saving measures: ', ME.message]);
                uialert(app.UIFigure, 'Failed to save the measures. Please try again.', 'Error', 'Icon', 'error');
            end
        end

        % Button pushed function: SortbynameButton
        function SortbynameButtonPushed(app, event)
            try
                % Check if data is loaded
                if isempty(app.TimeSeriesFiles)
                    uialert(app.UIFigure, 'No time series files to sort. Please load data first.', 'Error', 'Icon', 'error');
                    return;
                end
        
                % Get current selection to maintain it after sorting
                currentSelection = app.CurrentlistoftimeseriesListBox.Value;
                
                % Sort the TimeSeriesFiles array alphabetically
                [sortedFiles, sortIdx] = sort(app.TimeSeriesFiles);
                
                % Reorder the AllTimeSeriesData array to match
                sortedData = app.AllTimeSeriesData(sortIdx);
                
                % Update the app properties
                app.TimeSeriesFiles = sortedFiles;
                app.AllTimeSeriesData = sortedData;
                
                % Update the ListBox with sorted names
                app.CurrentlistoftimeseriesListBox.Items = sortedFiles;
                
                % Try to maintain the previous selection if it still exists
                if ~isempty(currentSelection) && any(strcmp(sortedFiles, currentSelection))
                    app.CurrentlistoftimeseriesListBox.Value = currentSelection;
                elseif ~isempty(sortedFiles)
                    app.CurrentlistoftimeseriesListBox.Value = sortedFiles{1};
                end
        
                % Notify the user that sorting was successful
                disp('Time series sorted alphabetically by name!');
                uialert(app.UIFigure, 'Time series sorted successfully by name.', 'Success', 'Icon', 'success');
            catch ME
                % Handle errors gracefully
                disp(['Error sorting time series: ', ME.message]);
                uialert(app.UIFigure, 'Failed to sort the data. Please try again.', 'Error', 'Icon', 'error');
            end
        end

        % Button pushed function: ExitButton
        function ExitButtonPushed(app, event)
            % Close the app's figure
            delete(app.UIFigure);
        end

        % Button pushed function: HelpButton
        function HelpButtonPushed(app, event)
            % Create help dialog with user guide
            helpText = sprintf([ ...
                'Time Series Analysis App - User Guide\n\n' ...
                '=== WORKFLOW ===\n' ...
                '1. Load Data: Click "Load time series" to import .txt files\n' ...
                '2. Preview: Click "Preview Time Series" to visualize your data\n' ...
                '3. Select Measures: Click "Select/run measures" to choose and compute measures\n' ...
                '4. View Results: Click "View measures" for visualizations and networks\n' ...
                '5. Save: Click "save measures" to export results\n\n' ...
                '=== AVAILABLE MEASURES ===\n' ...
                '• Mutual Information (MI): Nonlinear dependency\n' ...
                '• Cross-Correlation (CC): Linear correlation with lags\n' ...
                '• Granger Causality (GC): Linear predictive causality\n' ...
                '• Transfer Entropy (TE): Nonlinear information transfer\n' ...
                '• Partial Transfer Entropy (PTE): Conditional TE\n' ...
                '• Conditional Granger Causality (CGCI): Conditional GC\n\n' ...
                '=== DATA FORMAT ===\n' ...
                '• Text files with columns separated by tabs, spaces, or commas\n' ...
                '• First column can be time (optional)\n' ...
                '• Each column = one variable\n\n' ...
                '=== TIPS ===\n' ...
                '• Use "Sort by name" to organize multiple time series\n' ...
                '• Network plots: for CC, GC and CGCI only statistically significant\n' ...
                '  connections (p < alpha) are drawn; for MI, TE and PTE all connections\n' ...
                '  are drawn, with line width proportional to the value\n' ...
                '• Diagonal elements (a variable with itself) are not shown\n' ...
                '• Right-click graphs to export as images\n\n' ...
                'For more information, consult the documentation.']);
            
            % Create resizable help dialog
            dlg = uifigure('Name', 'Help - Quick Start Guide', 'Position', [100 100 800 650], 'Resize', 'on', 'AutoResizeChildren', 'off');
            txt = uitextarea(dlg, 'Value', helpText, 'Editable', 'off', ...
                'Position', [10 50 780 590], 'FontSize', 12);
            closeBtn = uibutton(dlg, 'push', 'Text', 'Close', ...
                'Position', [350 10 100 30], ...
                'ButtonPushedFcn', @(~,~) delete(dlg));
            % Make text area resize with window
            dlg.SizeChangedFcn = @(src,~) set(txt, 'Position', [10 50 src.Position(3)-20 src.Position(4)-60]);
        end

        % Button pushed function: SelectrunmeasuresButton
        function SelectrunmeasuresButtonPushed(app, event)
            % Check if data is loaded
            if isempty(app.LoadedTimeSeriesData)
                uialert(app.UIFigure, 'No time series data loaded. Please load data first.', 'Error', 'Icon', 'error');
                return;
            end
        
            % Create and show the second app
            secondAppInstance = secondApp;
            secondAppInstance.TimeSeriesData = app.LoadedTimeSeriesData;
            secondAppInstance.ParentApp = app;
            % Remove DTW from measures list if present
            if isfield(app.MeasureResults, 'DTW')
                app.MeasureResults = rmfield(app.MeasureResults, 'DTW');
            end
        end

        % Button pushed function: ViewmeasuresButton
        function ViewmeasuresButtonPushed(app, event)
            try
                % Check if any time series data is loaded
                if isempty(app.AllTimeSeriesData)
                    uialert(app.UIFigure, 'No time series data loaded. Please load data first.', 'Error', 'Icon', 'error');
                    return;
                end

                % Check if any measures have been computed
                if isempty(app.MeasureResults) || (~isfield(app.MeasureResults, 'MI') && ~isfield(app.MeasureResults, 'GC') && ~isfield(app.MeasureResults, 'CDMI') && ~isfield(app.MeasureResults, 'TE') && ~isfield(app.MeasureResults, 'CC') && ~isfield(app.MeasureResults, 'PTE') && ~isfield(app.MeasureResults, 'CGCI'))
                    uialert(app.UIFigure, 'No measures have been computed yet. Please run some measures first.', 'No Measures', 'Icon', 'error');
                    return;
                end

                % Initialize window counter for clean cascade positioning
                app.WindowCounter = 0;
                
                % No time series plot in View measures; proceed to network plots only
                figHandles = [];

                % --- Show weighted network plots for causal measures (TE, GC, CGCI, PTE) only ---
                % Skip network plots if too many variables (>10) as they become unreadable
                maxVarsForNetwork = 10;
                
                if isfield(app.MeasureResults, 'PTE') && ~isempty(app.MeasureResults.PTE)
                    pteMatrix = app.MeasureResults.PTE;
                    if size(pteMatrix, 1) <= maxVarsForNetwork
                        varNames = app.getMeasureVarNames(size(pteMatrix,1));
                        app.showPTENetworkPlot(pteMatrix, varNames);
                        figHandles(end+1) = gcf;
                    end
                end
                if isfield(app.MeasureResults, 'TE') && ~isempty(app.MeasureResults.TE)
                    teMatrix = app.MeasureResults.TE;
                    if size(teMatrix, 1) <= maxVarsForNetwork
                        varNames = app.getMeasureVarNames(size(teMatrix,1));
                        app.showDirectedNetworkPlot(teMatrix, varNames, 'Transfer Entropy Network', true);
                        figHandles(end+1) = gcf;
                    end
                end
                if isfield(app.MeasureResults, 'GC') && ~isempty(app.MeasureResults.GC)
                    gcMatrix = app.MeasureResults.GC;
                    if size(gcMatrix, 1) <= maxVarsForNetwork
                        gcMatrix(~isfinite(gcMatrix)) = 0;
                        gcMatrix(gcMatrix < 0) = 0;
                        % If the F-test was performed, draw only the significant
                        % edges (p < alpha), so that the graph is a causality network.
                        netMatrix = gcMatrix;
                        titleSuffix = ' (all edges, no significance test)';
                        if isfield(app.MeasureResults, 'GC_p') && ~isempty(app.MeasureResults.GC_p)
                            alpha = 0.05;
                            pG = app.MeasureResults.GC_p;
                            netMatrix(~(pG < alpha)) = 0;
                            titleSuffix = sprintf(' (significant edges, p<%.2f)', alpha);
                        end
                        varNames = app.getMeasureVarNames(size(gcMatrix,1));
                        app.showDirectedNetworkPlot(netMatrix, varNames, ['Granger Causality Network' titleSuffix], true);
                        figHandles(end+1) = gcf;
                    end
                end
                if isfield(app.MeasureResults, 'CGCI') && ~isempty(app.MeasureResults.CGCI)
                    cgciMatrix = app.MeasureResults.CGCI;
                    if size(cgciMatrix, 1) <= maxVarsForNetwork
                        cgciMatrix(~isfinite(cgciMatrix)) = 0;
                        cgciMatrix(cgciMatrix < 0) = 0;
                        % If the F-test was performed, draw only the significant edges.
                        netMatrix = cgciMatrix;
                        titleSuffix = ' (all edges, no significance test)';
                        if isfield(app.MeasureResults, 'CGCI_p') && ~isempty(app.MeasureResults.CGCI_p)
                            alpha = 0.05;
                            pC = app.MeasureResults.CGCI_p;
                            netMatrix(~(pC < alpha)) = 0;
                            titleSuffix = sprintf(' (significant edges, p<%.2f)', alpha);
                        end
                        varNames = app.getMeasureVarNames(size(cgciMatrix,1));
                        app.showDirectedNetworkPlot(netMatrix, varNames, ['Conditional Granger Causality Network' titleSuffix], true);
                        figHandles(end+1) = gcf;
                    end
                end
                % Show separate heatmaps and tables for each available measure
                try
                    if isfield(app.MeasureResults, 'MI') && ~isempty(app.MeasureResults.MI)
                        M_original = app.MeasureResults.MI;
                        varNames = app.getMeasureVarNames(size(M_original,1));
                        
                        % Sanitize NaNs (off-diagonal -> 0) and alert user if any were found
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M_original);
                        if nNaNOff > 0
                            app.alertNaNs('Mutual Information', nNaNOff, Mclean);
                        end
                        
                        % Show MI matrix with all values
                        fh = app.showMeasureMatrixHeatmap(Mclean, varNames, 'Mutual Information Matrix', true);
                        if ~isempty(fh), figHandles(end+1) = fh; end
                        
                        % Network plot with all MI values. For zero lag MI is
                        % symmetric (undirected graph); for a positive lag the
                        % two directions differ (directed graph).
                        if size(Mclean, 1) <= maxVarsForNetwork
                            miLag = 0;
                            if isfield(app.MeasureResults, 'MI_lag') && ~isempty(app.MeasureResults.MI_lag)
                                miLag = app.MeasureResults.MI_lag;
                            end
                            app.showDirectedNetworkPlot(Mclean, varNames, ...
                                sprintf('Mutual Information Network (lag=%d)', miLag), miLag > 0);
                            figHandles(end+1) = gcf;
                        end
                    end
                    if isfield(app.MeasureResults, 'CC') && ~isempty(app.MeasureResults.CC)
                        % Use the raw Cross-Correlation values (signed r) for both
                        % the table and the network plot. Significance is conveyed
                        % separately through the significance heatmap below.
                        M = app.MeasureResults.CC;
                        titleSuffix = '';
                        if isfield(app.MeasureResults, 'CC_sig') && ~isempty(app.MeasureResults.CC_sig)
                            % Build title suffix from stored metadata if available
                            try
                                if isfield(app.MeasureResults, 'CC_thr') && isfield(app.MeasureResults, 'CC_lagUsed')
                                    if isfield(app.MeasureResults, 'CC_alpha')
                                        titleSuffix = sprintf(' (α=%.3f, |r|≥%.3f, lag=%d)', ...
                                            app.MeasureResults.CC_alpha, app.MeasureResults.CC_thr, app.MeasureResults.CC_lagUsed);
                                    else
                                        titleSuffix = sprintf(' (|r|≥%.3f, lag=%d)', ...
                                            app.MeasureResults.CC_thr, app.MeasureResults.CC_lagUsed);
                                    end
                                end
                            catch
                            end
                        end
                        varNames = app.getMeasureVarNames(size(M,1));
                        % Sanitize NaNs (off-diagonal -> 0) and alert
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M);
                        if nNaNOff > 0
                            app.alertNaNs('Cross-Correlation', nNaNOff, Mclean);
                        end
                        % Separate heatmap and table
                        title = ['Cross-Correlation Matrix' titleSuffix];
                        fh = app.showMeasureMatrixHeatmap(Mclean, varNames, title);
                        if ~isempty(fh), figHandles(end+1) = fh; end
                        
                        % Show significance heatmap if significance data is available
                        if isfield(app.MeasureResults, 'CC_sig') && ~isempty(app.MeasureResults.CC_sig)
                            sigTitle = ['Cross-Correlation Significance' titleSuffix];
                            app.showSignificanceHeatmap(double(app.MeasureResults.CC_sig), varNames, sigTitle);
                            figHandles(end+1) = gcf;
                        end
                        
                        % Network graph for CC: only significant edges (if the
                        % t-test was performed); undirected for lag 0, directed otherwise.
                        if size(Mclean, 1) <= maxVarsForNetwork
                            ccNet = Mclean;
                            ccNet(~isfinite(ccNet)) = 0;
                            if isfield(app.MeasureResults, 'CC_sig') && ~isempty(app.MeasureResults.CC_sig) ...
                                    && isequal(size(app.MeasureResults.CC_sig), size(ccNet))
                                ccNet(~logical(app.MeasureResults.CC_sig)) = 0;
                                netSuffix = ' (significant edges)';
                            else
                                netSuffix = ' (all edges, no significance test)';
                            end
                            ccLag = 0;
                            if isfield(app.MeasureResults, 'CC_lagUsed') && ~isempty(app.MeasureResults.CC_lagUsed)
                                ccLag = app.MeasureResults.CC_lagUsed;
                            end
                            app.showDirectedNetworkPlot(ccNet, varNames, ['Cross-Correlation Network' netSuffix], ccLag > 0);
                            figHandles(end+1) = gcf;
                        end
                    end
                    if isfield(app.MeasureResults, 'TE') && ~isempty(app.MeasureResults.TE)
                        M = app.MeasureResults.TE;
                        varNames = app.getMeasureVarNames(size(M,1));
                        % Sanitize NaNs and alert
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M);
                        if nNaNOff > 0
                            app.alertNaNs('Transfer Entropy', nNaNOff, Mclean);
                        end
                        fh = app.showMeasureMatrixHeatmap(Mclean, varNames, 'Transfer Entropy Matrix');
                        if ~isempty(fh), figHandles(end+1) = fh; end
                    end
                    if isfield(app.MeasureResults, 'PTE') && ~isempty(app.MeasureResults.PTE)
                        M = app.MeasureResults.PTE;
                        varNames = app.getMeasureVarNames(size(M,1));
                        % Sanitize NaNs and alert
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M);
                        if nNaNOff > 0
                            app.alertNaNs('Partial Transfer Entropy', nNaNOff, Mclean);
                        end
                        fh = app.showMeasureMatrixHeatmap(Mclean, varNames, 'Partial Transfer Entropy Matrix');
                        if ~isempty(fh), figHandles(end+1) = fh; end
                    end
                    if isfield(app.MeasureResults, 'GC') && ~isempty(app.MeasureResults.GC)
                        M = app.MeasureResults.GC;
                        titleSuffix = '';
                        varNames = app.getMeasureVarNames(size(M,1));
                        % If F-test p-values are available, filter and show significance
                        gcTestOn = isfield(app.MeasureResults, 'GC_maketest') && app.MeasureResults.GC_maketest;
                        if gcTestOn && isfield(app.MeasureResults, 'GC_p') && ~isempty(app.MeasureResults.GC_p)
                            alpha = 0.05;
                            pMat = app.MeasureResults.GC_p;
                            titleSuffix = sprintf(' (p<%.2f)', alpha);
                        end
                        % Sanitize NaNs and alert
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M);
                        if nNaNOff > 0
                            app.alertNaNs('Granger Causality Index', nNaNOff, Mclean);
                        end
                        % No value heatmap for GC (value shown via Show Matrices table)

                        % If F-test p-values are available, show them too (use same helpers)
                        try
                            if gcTestOn && isfield(app.MeasureResults, 'GC_p') && ~isempty(app.MeasureResults.GC_p)
                                pMat = app.MeasureResults.GC_p;
                                [pClean, ~] = app.sanitizePMatrix(pMat); % replace NaNs with 1 (non-significant)
                                fhp = app.showMeasureMatrixHeatmap(pClean, varNames, 'Granger Causality p-values (F-test)');
                                if ~isempty(fhp), figHandles(end+1) = fhp; end
                                % Show significance heatmap
                                sigMask = (pClean < alpha);
                                sigTitle = ['Granger Causality Significance' titleSuffix];
                                app.showSignificanceHeatmap(double(sigMask), varNames, sigTitle);
                                figHandles(end+1) = gcf;
                            end
                        catch
                        end
                    end
                    if isfield(app.MeasureResults, 'CGCI') && ~isempty(app.MeasureResults.CGCI)
                        M = app.MeasureResults.CGCI;
                        titleSuffix = '';
                        varNames = app.getMeasureVarNames(size(M,1));
                        % If F-test p-values are available, filter and show significance
                        cgciTestOn = isfield(app.MeasureResults, 'CGCI_maketest') && app.MeasureResults.CGCI_maketest;
                        if cgciTestOn && isfield(app.MeasureResults, 'CGCI_p') && ~isempty(app.MeasureResults.CGCI_p)
                            alpha = 0.05;
                            pMat = app.MeasureResults.CGCI_p;
                            titleSuffix = sprintf(' (p<%.2f)', alpha);
                        end
                        % Sanitize NaNs and alert
                        [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(M);
                        if nNaNOff > 0
                            app.alertNaNs('Conditional Granger Causality Index', nNaNOff, Mclean);
                        end
                        % No value heatmap for CGCI (value shown via Show Matrices table)

                        % If F-test p-values are available for CGCI, show them too (use same helpers)
                        try
                            if cgciTestOn && isfield(app.MeasureResults, 'CGCI_p') && ~isempty(app.MeasureResults.CGCI_p)
                                pMat = app.MeasureResults.CGCI_p;
                                [pClean, ~] = app.sanitizePMatrix(pMat);
                                fhp = app.showMeasureMatrixHeatmap(pClean, varNames, 'CGCI p-values (F-test)');
                                if ~isempty(fhp), figHandles(end+1) = fhp; end
                                % Show significance heatmap
                                sigMask = (pClean < alpha);
                                sigTitle = ['CGCI Significance' titleSuffix];
                                app.showSignificanceHeatmap(double(sigMask), varNames, sigTitle);
                                figHandles(end+1) = gcf;
                            end
                        catch
                        end
                    end
                catch
                end
                if ~isempty(figHandles)
                    app.arrangeFigures(figHandles);
                end
                % Update the main list of measures in the UI
                app.updateCurrentMeasuresList();
                return;
            catch ME
                uialert(app.UIFigure, ['Error displaying results: ' ME.message], 'Error', 'Icon', 'error');
            end
        end
        
        % --- Show Mutual Information Table (raw and normalized) and Plot in separate windows ---
        function showMITableAndPlot(app)
            if ~isfield(app.MeasureResults, 'MI') || isempty(app.MeasureResults.MI)
                uialert(app.UIFigure, 'No Mutual Information results to display.', 'Error', 'Icon', 'error');
                return;
            end
            meaM = app.MeasureResults.MI;
            nnode = size(meaM,1);
            % Try to get variable names
            varNames = app.getMeasureVarNames(nnode);
            % --- Show MI Table (raw values, empty diagonal) ---
            meaShow = meaM; meaShow(1:nnode+1:end) = NaN;
            fTableRaw = uifigure('Name', 'Mutual Information Table', 'Position', [100 550 600 400]);
            uitRaw = uitable(fTableRaw, 'Data', app.matrixToTableData(meaShow, 3), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
            % Note: Do not draw weighted network plot here; 'View matrices' should show only tables.
        end

        

        % --- Custom PTE network plot with PTE values on the lines ---
        function showPTENetworkPlot(app, pteMatrix, varNames)
            % Replace non-finite values with zero
            pteMatrix(~isfinite(pteMatrix)) = 0;
            n = size(pteMatrix,1);
            % Remove self-loops (diagonal)
            if size(pteMatrix,2) == n
                pteMatrix(1:n+1:end) = 0;
            end
            G = digraph(pteMatrix, varNames);
            fh = figure('Name','Partial Transfer Entropy Network');
            % Always label nodes with the real variable names; show edge weight
            % labels for small graphs only, to keep larger ones readable.
            h = plot(G, 'Layout', 'circle', 'NodeLabel', string(varNames));
            if n <= 8
                edgeLabels = compose('%.2f', G.Edges.Weight);
                app.addOffsetEdgeLabels(h, G, edgeLabels);
            end
            if isprop(h, 'NodeLabelRotation')
                h.NodeLabelRotation = 0;
            end
            edgeWidths = G.Edges.Weight;
            edgeWidths(~isfinite(edgeWidths)) = 0;
            set(h,'LineWidth', app.scaleEdgeWidths(edgeWidths));
            title('Partial Transfer Entropy Network');
        end

        % --- Generic network plot; undirected if symmetric, directed otherwise ---
        function showDirectedNetworkPlot(app, weightMatrix, varNames, plotTitle, isDirected)
            % isDirected (optional): true for directed measures, false for
            % symmetric ones. The type is determined by the measure itself;
            % only if it is not given is it inferred from the matrix symmetry.
            W = weightMatrix;
            W(~isfinite(W)) = 0;
            n = size(W,1);
            % Remove self-loops (diagonal) for both directed and undirected cases
            if size(W,2) == n
                W(1:n+1:end) = 0;
            end
            % If symmetric (undirected measure), draw undirected graph without arrows
            tol = 1e-10;
            if nargin < 5 || isempty(isDirected)
                isDirected = ~(size(W,1) == size(W,2) && all(all(abs(W - W') <= tol)));
            end
            if ~isDirected
                % Symmetric measure: use the upper triangle
                Ws = triu(W, 1); Ws = Ws + Ws';
                G = graph(Ws, varNames);
                fh = figure('Name', plotTitle);
                % Always label nodes with the real variable names; show edge
                % weight labels for small graphs only, to keep larger ones readable.
                h = plot(G, 'Layout', 'circle', 'NodeLabel', string(varNames));
                if n <= 8
                    edgeLabels = compose('%.2f', G.Edges.Weight);
                    app.addOffsetEdgeLabels(h, G, edgeLabels);
                end
                if isprop(h, 'NodeLabelRotation')
                    h.NodeLabelRotation = 0;
                end
                edgeWidths = G.Edges.Weight;
                edgeWidths(~isfinite(edgeWidths)) = 0;
                set(h, 'LineWidth', app.scaleEdgeWidths(edgeWidths));
                title(plotTitle);
            else
                % Directed plot for asymmetric measures
                G = digraph(W, varNames);
                fh = figure('Name', plotTitle);
                % Always label nodes with the real variable names; show edge
                % weight labels for small graphs only, to keep larger ones readable.
                h = plot(G, 'Layout', 'circle', 'NodeLabel', string(varNames));
                if n <= 8
                    edgeLabels = compose('%.2f', G.Edges.Weight);
                    app.addOffsetEdgeLabels(h, G, edgeLabels);
                end
                if isprop(h, 'NodeLabelRotation')
                    h.NodeLabelRotation = 0;
                end
                edgeWidths = G.Edges.Weight;
                edgeWidths(~isfinite(edgeWidths)) = 0;
                set(h, 'LineWidth', app.scaleEdgeWidths(edgeWidths));
                title(plotTitle);
            end
        end

        % --- Map edge weights to readable line widths, normalized so a single
        %     dominant weight does not swamp all the other edges visually ---
        function lw = scaleEdgeWidths(~, edgeWidths)
            w = abs(edgeWidths(:));
            w(~isfinite(w)) = 0;
            mx = max(w);
            if isempty(mx) || mx <= 0
                lw = ones(size(w));
            else
                lw = 0.5 + 4.5 * (w / mx);
            end
        end

        function addOffsetEdgeLabels(app, h, G, edgeLabels)
            if isempty(edgeLabels)
                return;
            end
            try
                ax = ancestor(h, 'axes');
                endNodes = G.Edges.EndNodes;
                nEdges = size(endNodes, 1);
                if nEdges == 0
                    return;
                end
                x = h.XData;
                y = h.YData;
                xRange = max(x) - min(x);
                yRange = max(y) - min(y);
                offsetScale = 0.04 * max([xRange, yRange, 1]);
                for k = 1:nEdges
                    sIdx = findnode(G, endNodes(k, 1));
                    tIdx = findnode(G, endNodes(k, 2));
                    if sIdx == 0 || tIdx == 0
                        continue;
                    end
                    x1 = x(sIdx); y1 = y(sIdx);
                    x2 = x(tIdx); y2 = y(tIdx);
                    xm = (x1 + x2) / 2;
                    ym = (y1 + y2) / 2;
                    dx = x2 - x1;
                    dy = y2 - y1;
                    normVal = hypot(dx, dy);
                    if normVal == 0
                        offset = [0 0];
                    else
                        offset = offsetScale * [-dy, dx] / normVal;
                    end
                    text(ax, xm + offset(1), ym + offset(2), edgeLabels(k), ...
                        'HorizontalAlignment', 'center', 'FontSize', 8, 'Color', [0 0 0]);
                end
            catch
            end
        end
        
        % --- Generic heatmap for any measure matrix ---
        function hFig = showMeasureMatrixHeatmap(app, measureMatrix, varNames, plotTitle, maskDiagonal)
            hFig = [];
            try
                if isempty(measureMatrix)
                    return;
                end
                M = measureMatrix;
                M(~isfinite(M)) = NaN;
                % Hide diagonal for color scaling in plots
                if nargin < 5 || isempty(maskDiagonal)
                    maskDiagonal = true;
                end
                n = size(M,1);
                if maskDiagonal && n == size(M,2)
                    M(1:n+1:end) = NaN;
                end
                minVal = min(M(:), [], 'omitnan');
                maxVal = max(M(:), [], 'omitnan');
                if nargin < 3 || isempty(varNames)
                    nVars = size(M,1);
                    varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                end
                % Create separate heatmap window with cascade positioning
                pos = app.getNextWindowPosition();
                hFig = figure('Name', [plotTitle ' - Heatmap'], 'NumberTitle', 'off', 'Position', pos);
                ax = axes('Parent', hFig, 'Position', [0.1 0.1 0.75 0.8]);
                hImg = imagesc(ax, M);
                set(hImg, 'AlphaData', ~isnan(M));   % NaN cells (diagonal) left blank
                set(ax, 'Color', [0.85 0.85 0.85]);
                if ~isempty(minVal) && ~isempty(maxVal) && isfinite(minVal) && isfinite(maxVal) && maxVal > minVal
                    caxis(ax, [minVal maxVal]);
                end
                colorbar(ax);
                title(ax, plotTitle);
                nVars = length(varNames);
                if nVars > 30
                    % Hide tick labels for large matrices to avoid clutter
                    set(ax, 'XTick', [], 'XTickLabel', [], 'YTick', [], 'YTickLabel', []);
                else
                    set(ax, 'XTick', 1:nVars, 'XTickLabel', varNames, 'YTick', 1:nVars, 'YTickLabel', varNames);
                end
                xlabel(ax, 'To Variable'); ylabel(ax, 'From Variable');
            catch
            end
        end

        % --- Generic table for any measure matrix ---
        function tFig = showMeasureMatrixTable(app, measureMatrix, varNames, plotTitle, decimals)
            tFig = [];
            try
                if isempty(measureMatrix)
                    return;
                end
                if nargin < 3 || isempty(varNames)
                    nVars = size(measureMatrix,1);
                    varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                end
                % Decimal places for display. Default 3. Pass NaN to skip
                % rounding so small values (e.g. GCI/CGCI at low order) are
                % shown in full precision instead of rounding to 0.000.
                if nargin < 5 || isempty(decimals)
                    decimals = 3;
                end
                if isnan(decimals)
                    dataToShow = measureMatrix;
                else
                    dataToShow = round(measureMatrix, decimals);
                end
                % Create separate table window with cascade positioning
                pos = app.getNextWindowPosition();
                tFig = uifigure('Name', [plotTitle ' - Table'], 'Position', pos);
                uitable(tFig, 'Data', dataToShow, 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 25 pos(3)-50 pos(4)-50]);
            catch
            end
        end
        
        % Helper: get next window position with cascade offset
        function pos = getNextWindowPosition(app)
            % Standard window size
            stdWidth = 700;
            stdHeight = 550;
            
            % Base position (top-left of screen area)
            baseX = 150;
            baseY = 100;
            
            % Cascade offset
            offsetStep = 40;
            
            % Increment counter
            if ~isprop(app, 'WindowCounter') || isempty(app.WindowCounter)
                app.WindowCounter = 0;
            end
            app.WindowCounter = app.WindowCounter + 1;
            
            % Calculate cascaded position (reset every 10 windows)
            offset = mod(app.WindowCounter - 1, 10) * offsetStep;
            pos = [baseX + offset, baseY + offset, stdWidth, stdHeight];
        end
        
        % Helper: compute downsample stride from UI controls
        function ds = computeDsFromControls(app, dsMode, dsSpin, tgtSpin, nPoints)
            try
                switch dsMode.Value
                    case 'Auto'
                        tp = max(1, round(tgtSpin.Value));
                        ds = max(1, ceil(nPoints / tp));
                    case 'Manual'
                        ds = max(1, round(dsSpin.Value));
                    otherwise % 'None'
                        ds = 1;
                end
            catch
                ds = 1;
            end
        end
        
        % Helper: update visibility of downsample controls based on mode
        function updateDsControlVisibility(app, dsMode, dsSpin, dsSpinLbl, tgtSpin, tgtLbl)
            try
                isAuto = strcmp(dsMode.Value,'Auto');
                isManual = strcmp(dsMode.Value,'Manual');
                % Manual controls
                if isvalid(dsSpin), dsSpin.Visible = isManual; end
                if isvalid(dsSpinLbl), dsSpinLbl.Visible = isManual; end
                % Auto controls
                if isvalid(tgtSpin), tgtSpin.Visible = isAuto; end
                if isvalid(tgtLbl), tgtLbl.Visible = isAuto; end
            catch
            end
        end
        
        % Helper: handle mode change - update visibility and replot
        function handleDsModeChangeAndReplot(app, dsMode, dsSpin, dsSpinLbl, tgtSpin, tgtLbl, ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, customTitle)
            try
                app.updateDsControlVisibility(dsMode, dsSpin, dsSpinLbl, tgtSpin, tgtLbl);
                % Use current selection from UserData if available
                if isfield(ax.UserData, 'selectedNames') && ~isempty(ax.UserData.selectedNames)
                    selectedNames = ax.UserData.selectedNames;
                end
                ds = app.computeDsFromControls(dsMode, dsSpin, tgtSpin, size(yAll,1));
                app.replotViewMeasures(ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, ds, customTitle);
            catch
            end
        end

        % Helper: replot with current selection from axes UserData
        function replotWithCurrentSelection(app, ax, styleDrop, infoLbl)
            try
                xAll = ax.UserData.xAll;
                yAll = ax.UserData.yAll;
                names = ax.UserData.names;
                selectedNames = ax.UserData.selectedNames;
                customTitle = ax.UserData.customTitle;
                dsMode = ax.UserData.dsMode;
                dsSpin = ax.UserData.dsSpin;
                tgtSpin = ax.UserData.tgtSpin;
                ds = app.computeDsFromControls(dsMode, dsSpin, tgtSpin, size(yAll,1));
                app.replotViewMeasures(ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, ds, customTitle);
            catch
            end
        end

        % Helper: open variable selector for preview window
        function openVariableSelectorForPreview(app, parentFig, ax, styleDrop, infoLbl)
            try
                names = ax.UserData.names;
                selectedNames = ax.UserData.selectedNames;
                
                % Create modal variable selector dialog
                varFig = uifigure('Name', 'Select Variables', 'Position', [100 200 300 400], 'WindowStyle', 'modal');
                gl = uigridlayout(varFig, [3 1]);
                gl.RowHeight = {'fit', '1x', 'fit'};
                
                % Instructions
                instrLbl = uilabel(gl, 'Text', 'Select variables to display (Ctrl+click for multiple):');
                instrLbl.Layout.Row = 1; instrLbl.Layout.Column = 1;
                
                % Variable list
                varList = uilistbox(gl, 'Items', names, 'Multiselect', 'on', 'Value', selectedNames);
                varList.Layout.Row = 2; varList.Layout.Column = 1;
                
                % Buttons
                btnPanel = uipanel(gl);
                btnPanel.Layout.Row = 3; btnPanel.Layout.Column = 1;
                btnGL = uigridlayout(btnPanel, [1 3]);
                btnGL.ColumnWidth = {'1x', 'fit', 'fit'};
                
                selectAllBtn = uibutton(btnGL, 'Text', 'Select All', 'ButtonPushedFcn', @(~,~) set(varList, 'Value', names));
                selectAllBtn.Layout.Row = 1; selectAllBtn.Layout.Column = 2;
                
                applyBtn = uibutton(btnGL, 'Text', 'Apply', 'ButtonPushedFcn', @(~,~) app.applyVariableSelectionForPreview(varFig, varList, ax, styleDrop, infoLbl));
                applyBtn.Layout.Row = 1; applyBtn.Layout.Column = 3;
            catch ME
                try delete(varFig); catch, end
                uialert(parentFig, ['Error opening variable selector: ' ME.message], 'Error', 'Icon', 'error');
            end
        end

        % Helper: apply variable selection for preview window
        function applyVariableSelectionForPreview(app, varFig, varList, ax, styleDrop, infoLbl)
            try
                selectedVars = varList.Value;
                if isempty(selectedVars)
                    selectedVars = ax.UserData.names;
                end
                % Update selection in UserData
                ax.UserData.selectedNames = selectedVars;
                % Replot with new selection
                app.replotWithCurrentSelection(ax, styleDrop, infoLbl);
                delete(varFig);
            catch ME
                uialert(varFig, ['Error applying selection: ' ME.message], 'Error', 'Icon', 'error');
            end
        end

        % Helper: write labeled matrix block to an open text file
        function writeLabeledMatrixToFile(app, fid, label, matrix, normalizeFlag, varNames)
            try
                if isempty(matrix) || ~isscalar(fid) || fid == -1
                    return;
                end
                M = matrix;
                if ~isnumeric(M)
                    try
                        M = double(M);
                    catch
                        return;
                    end
                end
                if nargin < 6
                    varNames = [];
                end
                if nargin < 5 || isempty(normalizeFlag)
                    normalizeFlag = false;
                end
                if normalizeFlag
                    minVal = min(M(:));
                    maxVal = max(M(:));
                    if isfinite(minVal) && isfinite(maxVal) && maxVal > minVal
                        M = (M - minVal) / (maxVal - minVal);
                    end
                end
                nVars = size(M, 1);
                if isempty(varNames)
                    vnames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                else
                    vnames = varNames;
                end
                if numel(vnames) ~= nVars
                    vnames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
                end
                % Compute column widths based on header and numbers
                maxVarLen = max(cellfun(@length, vnames));
                colWidths = zeros(1, numel(vnames));
                for j = 1:numel(vnames)
                    numWidths = arrayfun(@(ii) length(sprintf('%.6f', M(ii,j))), 1:size(M,1));
                    colWidths(j) = max([length(vnames{j}), numWidths]);
                end
                % Header
                fprintf(fid, '%s\n', label);
                fprintf(fid, sprintf('%%-%ds', maxVarLen+2), '');
                for j = 1:numel(vnames)
                    fmt = sprintf('%%-%ds', colWidths(j)+2);
                    fprintf(fid, fmt, vnames{j});
                end
                fprintf(fid, '\n');
                % Rows
                for i = 1:size(M,1)
                    fprintf(fid, sprintf('%%-%ds', maxVarLen+2), vnames{i});
                    for j = 1:size(M,2)
                        fmt = sprintf('%%-%d.6f', colWidths(j)+2);
                        fprintf(fid, fmt, M(i,j));
                    end
                    fprintf(fid, '\n');
                end
                fprintf(fid, '\n');
            catch
            end
        end

        % --- Time series visualization with controls ---
        function showTimeSeriesPlot(app, customTitle, varIdx)
            if isempty(app.LoadedTimeSeriesData)
                return;
            end
            if nargin < 2 || isempty(customTitle)
                customTitle = 'Time Series';
            end
            
            % Prepare data as a table for processing
            if istable(app.LoadedTimeSeriesData)
                dataTbl = app.LoadedTimeSeriesData;
            elseif isnumeric(app.LoadedTimeSeriesData)
                dataTbl = array2table(app.LoadedTimeSeriesData);
                nVars = size(app.LoadedTimeSeriesData, 2);
                dataTbl.Properties.VariableNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
            else
                return;
            end
            
            % Create interactive time series window
            f = uifigure('Name', customTitle, 'Position', [100 100 900 650]);
            gl = uigridlayout(f, [2 1]);
            gl.ColumnWidth = {'1x'}; gl.RowHeight = {'fit','1x'};
            
            % Top: controls
            ctrl = uipanel(gl, 'Title', 'Controls');
            ctrl.Layout.Row = 1; ctrl.Layout.Column = 1;
            gc = uigridlayout(ctrl, [2 9]);
            gc.ColumnWidth = {'fit','fit','fit','fit','fit','fit','fit','1x','fit'}; 
            gc.RowHeight = {'fit','fit'};

            % Style controls
            styleLbl = uilabel(gc,'Text','Style');
            styleLbl.Layout.Row = 1; styleLbl.Layout.Column = 1;
            styleDrop = uidropdown(gc,'Items',{'lines','dots','line+markers'},'Value','lines');
            styleDrop.Layout.Row = 1; styleDrop.Layout.Column = 2;

            % Downsampling mode
            dsModeLbl = uilabel(gc,'Text','Downsample');
            dsModeLbl.Layout.Row = 1; dsModeLbl.Layout.Column = 3;
            dsMode = uidropdown(gc,'Items',{'Auto','Manual','None'},'Value','None');
            dsMode.Layout.Row = 1; dsMode.Layout.Column = 4;

            % Manual stride spinner
            dsSpinLbl = uilabel(gc,'Text','Stride');
            dsSpinLbl.Layout.Row = 2; dsSpinLbl.Layout.Column = 1;
            dsSpin = uispinner(gc,'Limits',[1 Inf],'Step',1,'Value',1);
            dsSpin.Layout.Row = 2; dsSpin.Layout.Column = 2;

            % Auto target points spinner
            tgtLbl = uilabel(gc,'Text','Target pts');
            tgtLbl.Layout.Row = 2; tgtLbl.Layout.Column = 3;
            tgtSpin = uispinner(gc,'Limits',[100 Inf],'Step',100,'Value',500);
            tgtSpin.Layout.Row = 2; tgtSpin.Layout.Column = 4;

            % Select Variables button
            selectVarsBtn = uibutton(gc,'Text','Select Variables');
            selectVarsBtn.Layout.Row = 1; selectVarsBtn.Layout.Column = 5;

            % Info label
            infoLbl = uilabel(gc,'Text','');
            infoLbl.Layout.Row = 1; infoLbl.Layout.Column = 8;
            
            % Bottom: axes
            ax = uiaxes(gl);
            ax.Layout.Row = 2; ax.Layout.Column = 1;
            grid(ax, 'on');
            
            % Build time vector and Y matrix
            try
                xAll = (1:height(dataTbl))';
                if ~isempty(dataTbl) && isnumeric(dataTbl{:,1}) && all(isfinite(dataTbl{:,1}))
                    xAll = dataTbl{:,1};
                    xAll = xAll(:);
                end
                if width(dataTbl) >= 2
                    yAll = table2array(dataTbl(:, 2:end));
                    names = dataTbl.Properties.VariableNames(2:end);
                else
                    yAll = table2array(dataTbl(:, 1:end));
                    names = dataTbl.Properties.VariableNames(1:end);
                end
                
                % Set initial selection based on varIdx if provided
                if nargin >= 3 && ~isempty(varIdx)
                    selectedNames = names(varIdx);
                else
                    selectedNames = names;
                end
                
                % No variable selector in View measures: use all (optionally ordered)
                if exist('varIdx','var') && ~isempty(varIdx)
                    % Map order indices to names if within bounds
                    try
                        selIdx = varIdx(varIdx>=1 & varIdx<=numel(names));
                        selectedNames = names(selIdx);
                    catch
                        selectedNames = names;
                    end
                else
                    selectedNames = names;
                end

                % Store state in axes UserData for variable selector
                ax.UserData.xAll = xAll;
                ax.UserData.yAll = yAll;
                ax.UserData.names = names;
                ax.UserData.selectedNames = selectedNames;
                ax.UserData.customTitle = customTitle;
                ax.UserData.dsMode = dsMode;
                ax.UserData.dsSpin = dsSpin;
                ax.UserData.dsSpinLbl = dsSpinLbl;
                ax.UserData.tgtSpin = tgtSpin;
                ax.UserData.tgtLbl = tgtLbl;

                % Replot callback - compute ds and replot with current selection
                replotCallback = @(~,~) app.replotWithCurrentSelection(ax, styleDrop, infoLbl);
                
                % Combined callback for mode changes - update visibility then replot
                modeChangeCallback = @(~,~) app.handleDsModeChangeAndReplot(dsMode, dsSpin, dsSpinLbl, tgtSpin, tgtLbl, ...
                    ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, customTitle);

                % Select Variables button callback
                selectVarsBtn.ButtonPushedFcn = @(~,~) app.openVariableSelectorForPreview(f, ax, styleDrop, infoLbl);

                % Wire callbacks
                try styleDrop.ValueChangedFcn = replotCallback; catch, end
                try dsMode.ValueChangedFcn = modeChangeCallback; catch, end
                try dsSpin.ValueChangedFcn = replotCallback; catch, end
                try tgtSpin.ValueChangedFcn = replotCallback; catch, end

                % Initial state
                app.updateDsControlVisibility(dsMode, dsSpin, dsSpinLbl, tgtSpin, tgtLbl);
                app.replotWithCurrentSelection(ax, styleDrop, infoLbl);
            catch
                % Fallback to simple plot
                cla(ax);
                text(ax, 0.5, 0.5, 'Error displaying time series', 'HorizontalAlignment', 'center');
            end
        end

        

        

        

        % --- Order variables by node strength from measure matrix ---
        function orderIdx = orderVariablesByStrength(app, measureMatrix, isDirected)
            if nargin < 3
                isDirected = false;
            end
            W = abs(measureMatrix);
            n = size(W,1);
            W(1:n+1:end) = 0; % zero diagonal
            if ~isDirected
                % undirected: strength is sum across row (same as col)
                strength = sum(W, 2);
            else
                % directed: use total strength in+out
                strength = sum(W, 2) + sum(W, 1)';
            end
            [~, orderIdx] = sort(strength, 'descend');
        end

        

        

        % New function: Handle selection in the time series list box
        function CurrentlistoftimeseriesListBoxValueChanged(app, event)
            % Get the selected time series files (can be multiple)
            selectedFiles = app.CurrentlistoftimeseriesListBox.Value;
            
            % If nothing is selected, return
            if isempty(selectedFiles) || (ischar(selectedFiles) && strcmp(selectedFiles, 'empty'))
                return;
            end
            
            % Handle single selection (load the data)
            if ischar(selectedFiles)
                selectedFiles = {selectedFiles};
            end
            
            % Load the first selected file's data (for single selection or first of multiple)
            if ~isempty(selectedFiles)
                firstFile = selectedFiles{1};
                idx = find(strcmp(app.TimeSeriesFiles, firstFile));
                if ~isempty(idx)
                    app.LoadedTimeSeriesData = app.AllTimeSeriesData{idx};
                    % Clear previous measures since we're switching to different data
                    app.MeasureResults = [];
                    % Update measures list display
                    app.updateCurrentMeasuresList();
                    if length(selectedFiles) == 1
                        disp(['Selected time series: ' firstFile]);
                    else
                        disp(['Selected ' num2str(length(selectedFiles)) ' time series files. Loaded: ' firstFile]);
                    end
                end
            end
        end

        % Button pushed function: DeleteButton
        function DeleteButtonPushed(app, event)
            try
                % Check if data is loaded
                if isempty(app.TimeSeriesFiles)
                    uialert(app.UIFigure, 'No time series files to delete. Please load data first.', 'Error', 'Icon', 'error');
                    return;
                end
                
                % Get the selected files (can be multiple)
                selectedFiles = app.CurrentlistoftimeseriesListBox.Value;
                
                % Check if files are selected
                if isempty(selectedFiles) || (ischar(selectedFiles) && strcmp(selectedFiles, 'empty'))
                    uialert(app.UIFigure, 'Please select one or more time series to delete.', 'No Selection', 'Icon', 'error');
                    return;
                end
                
                % Convert to cell array if single selection
                if ischar(selectedFiles)
                    selectedFiles = {selectedFiles};
                end
                
                % Create confirmation message
                if length(selectedFiles) == 1
                    confirmMsg = ['Are you sure you want to delete "' selectedFiles{1} '"?'];
                else
                    confirmMsg = ['Are you sure you want to delete ' num2str(length(selectedFiles)) ' selected time series?'];
                end
                
                % Confirm deletion
                choice = uiconfirm(app.UIFigure, confirmMsg, 'Confirm Deletion', ...
                    'Options', {'Yes', 'No'}, 'DefaultOption', 2, 'CancelOption', 2);
                
                if strcmp(choice, 'No')
                    return;
                end

                % Find indices of selected files and remove them
                indicesToRemove = [];
                for i = 1:length(selectedFiles)
                    idx = find(strcmp(app.TimeSeriesFiles, selectedFiles{i}));
                    if ~isempty(idx)
                        indicesToRemove = [indicesToRemove, idx];
                    end
                end
                
                % Sort indices in descending order to remove from end first
                indicesToRemove = sort(indicesToRemove, 'descend');
                
                % Remove files from lists
                for idx = indicesToRemove
                    app.TimeSeriesFiles(idx) = [];
                    app.AllTimeSeriesData(idx) = [];
                end
                
                % Update the ListBox
                if isempty(app.TimeSeriesFiles)
                    app.CurrentlistoftimeseriesListBox.Items = {'empty'};
                    app.CurrentlistoftimeseriesListBox.Value = 'empty';
                    app.LoadedTimeSeriesData = [];
                else
                    app.CurrentlistoftimeseriesListBox.Items = app.TimeSeriesFiles;
                    app.CurrentlistoftimeseriesListBox.Value = app.TimeSeriesFiles{1};
                    app.LoadedTimeSeriesData = app.AllTimeSeriesData{1};
                end
                
                % Notify the user that deletion was successful
                if length(selectedFiles) == 1
                    disp(['Time series "' selectedFiles{1} '" deleted successfully!']);
                    uialert(app.UIFigure, ['Time series "' selectedFiles{1} '" deleted successfully.'], 'Success', 'Icon', 'success');
                else
                    disp([num2str(length(selectedFiles)) ' time series deleted successfully!']);
                    uialert(app.UIFigure, [num2str(length(selectedFiles)) ' time series deleted successfully.'], 'Success', 'Icon', 'success');
                end
            catch ME
                % Handle errors gracefully
                disp(['Error deleting time series: ', ME.message]);
                uialert(app.UIFigure, 'Failed to delete the time series. Please try again.', 'Error', 'Icon', 'error');
            end
        end

        % Button pushed function: PreviewTimeSeriesButton
        function PreviewTimeSeriesButtonPushed(app, event)
            % Check if time series data is loaded
            if isempty(app.LoadedTimeSeriesData)
                uialert(app.UIFigure, 'No time series data loaded.', 'Error', 'Icon', 'error');
                return;
            end
            % Use the richer interactive viewer with downsampling and controls
            app.showTimeSeriesPlot('Time Series Preview');
        end

        

        % Sanitize numeric measure matrix: replace off-diagonal NaNs with a fill value
        % Returns cleaned matrix and the count of off-diagonal NaNs encountered
        function [Mout, nNaNOff] = sanitizeMeasureMatrix(app, Min, ~)
            % Non-finite off-diagonal values are KEPT as NaN (they are not
            % silently replaced by zero); their number is returned so that
            % the user can be informed. The diagonal (a variable with itself)
            % is not meaningful for any measure and is set to NaN (not shown).
            try
                M = Min;
                if isempty(M)
                    Mout = M;
                    nNaNOff = 0;
                    return;
                end
                M(~isfinite(M)) = NaN;
                [r,c] = size(M);
                diagMask = false(r,c);
                d = min(r,c);
                diagMask(1:d+1:end) = true;
                nNaNOff = nnz(isnan(M) & ~diagMask);
                M(diagMask) = NaN;
                Mout = M;
            catch
                Mout = Min;
                nNaNOff = 0;
            end
        end

        % Convert a measure matrix to table data: values rounded to the given
        % number of decimals; NaN entries (diagonal, failed pairs) shown empty.
        function C = matrixToTableData(~, M, decimals)
            if nargin < 3 || isempty(decimals)
                decimals = 4;
            end
            C = num2cell(round(M, decimals));
            C(isnan(M)) = {''};
        end

        % Sanitize p-value matrix for display: keep the computed p-values
        % exactly as they are (no normalization, no clipping). Only the
        % diagonal (self-pairs, which are not meaningful) is set to NaN.
        function [Pout, nNaN] = sanitizePMatrix(app, Pin)
            try
                P = Pin;
                nNaN = nnz(~isfinite(P));
                n = size(P,1);
                if n == size(P,2)
                    P(1:n+1:end) = NaN; % diagonal is not applicable
                end
                Pout = P;
            catch
                Pout = Pin;
                nNaN = 0;
            end
        end

        % Alert user about NaNs that indicate computation failure
        function alertNaNs(app, measureName, nCount, M)
            try
                if nCount <= 0
                    return;
                end
                % List the pairs that could not be computed
                pairStr = '';
                if nargin >= 4 && ~isempty(M)
                    vn = app.getMeasureVarNames(size(M,1));
                    Mm = M; n = min(size(Mm)); Mm(1:size(Mm,1)+1:size(Mm,1)*n) = 0;
                    [ri, ci] = find(isnan(Mm));
                    nShow = min(10, numel(ri));
                    parts = strings(nShow,1);
                    for q = 1:nShow
                        parts(q) = sprintf('  %s -> %s', vn{ri(q)}, vn{ci(q)});
                    end
                    pairStr = char(strjoin(parts, '\n'));
                    if numel(ri) > nShow
                        pairStr = sprintf('%s\n  ... and %d more', pairStr, numel(ri) - nShow);
                    end
                end
                msg = sprintf(['%d pair(s) in %s could not be computed:\n%s\n\n' ...
                               'These values are left empty in the tables and are not drawn in the plots.\n' ...
                               'Possible causes: insufficient samples after lag/embedding, constant signals, or ill-conditioned models.\n' ...
                               'Suggestions: increase data length, reduce model order/lags/bins, or check data quality.'], ...
                               nCount, measureName, pairStr);
                uialert(app.UIFigure, msg, 'Computation Warning', 'Icon', 'warning');
            catch
            end
        end

        % Nested function to update Y-limits based on visible X-range
        function updateYLimits(ax, xAll, yAll)
            try
                if isempty(ax) || ~isvalid(ax) || isempty(ax.Children) || isempty(xAll) || isempty(yAll)
                    return;
                end
                
                % Get current X-limits
                xlims = xlim(ax);
                
                % Find data points within current X-range
                inRange = xAll >= xlims(1) & xAll <= xlims(2);
                if ~any(inRange)
                    return;
                end
                
                % For each line in the plot, find min/max in visible range
                yMin = inf;
                yMax = -inf;
                hasData = false;
                
                for i = 1:length(ax.Children)
                    if isa(ax.Children(i), 'matlab.graphics.chart.primitive.Line')
                        xData = ax.Children(i).XData;
                        yData = ax.Children(i).YData;
                        
                        if isempty(xData) || isempty(yData)
                            continue;
                        end
                        
                        % Only consider points in current X-range
                        validIdx = xData >= xlims(1) & xData <= xlims(2);
                        if any(validIdx)
                            yMin = min(yMin, min(yData(validIdx)));
                            yMax = max(yMax, max(yData(validIdx)));
                            hasData = true;
                        end
                    end
                end
                
                % Only update if we have valid data
                if hasData && yMax > yMin
                    % Add 10% padding
                    yRange = yMax - yMin;
                    padding = yRange * 0.1;
                    ylim(ax, [yMin-padding, yMax+padding]);
                end
            catch ME
                % Silently handle any errors to prevent breaking the UI
                disp(['Error updating Y-limits: ' ME.message]);
            end
        end
        
        function replotPreview(app, ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, autoDS)
            try
                % Determine downsampling factor if autoDS is true
                if autoDS && numel(xAll) > 1000
                    ds = ceil(numel(xAll) / 1000);  % Target ~1000 points
                    x = xAll(1:ds:end);
                else
                    ds = 1;
                    x = xAll;
                end
                
                % Determine which variables to plot based on selection
                if nargin < 8 || isempty(selectedNames)
                    idx = 1:numel(names); % Default to all variables if none selected
                    namesSel = names;
                else
                    % Normalize selection to cellstr and map to indices preserving order
                    if isstring(selectedNames)
                        namesSel = cellstr(selectedNames);
                        namesSel = namesSel(:)';
                    elseif ischar(selectedNames)
                        namesSel = {selectedNames};
                    elseif iscell(selectedNames)
                        % Convert any strings inside cell to char, preserve order
                        try
                            namesSel = cellfun(@char, selectedNames, 'UniformOutput', false);
                        catch
                            namesSel = selectedNames;
                        end
                        namesSel = namesSel(:)';
                    else
                        namesSel = names;
                    end
                    % Map selected names to indices (preserving order), include all
                    [~, idx] = ismember(namesSel, names);
                    idx = idx(idx > 0);
                    if isempty(idx)
                        idx = 1:numel(names);
                        namesSel = names;
                    end
                end
                
                % Prepare data for plotting
                if ds > 1
                    y = yAll(1:ds:end, idx);
                else
                    y = yAll(:, idx);
                end
                
                % Clear previous plot and set up new one
                cla(ax);
                hold(ax, 'on');
                
                % Use different colors for each line
                colors = lines(numel(idx));
                
                % Plot each time series with its own color
                h = gobjects(1, numel(idx));
                for i = 1:numel(idx)
                    switch styleDrop.Value
                        case 'lines'
                            h(i) = plot(ax, x, y(:,i), 'LineWidth', 1.2, 'Color', colors(i,:));
                        case 'dots'
                            h(i) = plot(ax, x, y(:,i), 'LineStyle', 'none', 'Marker', '.', 'MarkerSize', 8, 'Color', colors(i,:));
                        case 'line+markers'
                            h(i) = plot(ax, x, y(:,i), '-o', 'LineWidth', 0.8, 'MarkerSize', 3, 'Color', colors(i,:));
                    end
                end
                
                % Set up axes and labels
                xlabel(ax, 'Time'); 
                ylabel(ax, 'Value');
                title(ax, sprintf('Time Series (%d of %d shown)', numel(idx), numel(names)), 'Interpreter', 'none');
                % If current XLim does not overlap data (initial open), set to full data extent
                try
                    if ~isempty(x)
                        xMin = min(x); xMax = max(x);
                        xl = ax.XLim;
                        validXL = isnumeric(xl) && numel(xl)==2 && all(isfinite(xl)) && xl(2) > xl(1);
                        overlap = validXL && (xl(2) >= xMin) && (xl(1) <= xMax);
                        if ~overlap
                            ax.XLim = [xMin xMax];
                        end
                    end
                catch
                end
                
                % Set x-axis limits to full and choose ticks
                try
                    if numel(x) > 1
                        xlim(ax, [x(1) x(end)]);
                    end
                catch
                end
                % Set x-axis ticks
                try
                    if numel(x) > 1
                        span = x(end) - x(1);
                        if span > 0
                            step = 10^floor(log10(span/8));
                            if step == 0, step = 1; end
                            ticks = x(1):step:x(end);
                            if numel(ticks) > 20  % Limit number of ticks
                                step = step * ceil(numel(ticks)/20);
                                ticks = x(1):step:x(end);
                            end
                            xticks(ax, ticks);
                        end
                    end
                    xtickformat(ax, '%.0f');
                catch
                end
                
                % Add legend with scrollable option if many variables
                if numel(idx) > 0
                    if numel(idx) > 10
                        % For many variables, create a scrollable legend
                        lgd = legend(ax, h, namesSel, 'Location', 'eastoutside', 'Interpreter', 'none');
                        lgd.Title.String = 'Variables';
                        lgd.NumColumns = 1 + floor(numel(idx)/15);
                        lgd.Box = 'on';
                    else
                        legend(ax, namesSel, 'Location', 'eastoutside', 'Interpreter', 'none');
                    end
                end
                
                % Apply Y-axis scaling
                try
                    if isfield(ax.UserData, 'yAxisDrop') && isvalid(ax.UserData.yAxisDrop)
                        if strcmp(ax.UserData.yAxisDrop.Value, 'Manual') && isfield(ax.UserData, 'YLimManual')
                            yl = ax.UserData.YLimManual;
                            if numel(yl) == 2 && isfinite(yl(1)) && isfinite(yl(2)) && yl(2) > yl(1)
                                ylim(ax, yl);
                            else
                                ylim(ax, 'auto');
                            end
                        else
                            ylim(ax, 'auto');
                        end
                    end
                catch
                end
                % No info label to update
                
                grid(ax, 'on');
                hold(ax, 'off');
                
                drawnow limitrate; % Update display without blocking
                
            catch ME
                try
                    if ~isempty(infoLbl) && isvalid(infoLbl)
                        infoLbl.Text = ['Error: ' ME.message];
                    end
                    disp(['Error in replotPreview: ' ME.message]);
                catch
                end
            end
        end

        function replotViewMeasures(app, ax, styleDrop, infoLbl, xAll, yAll, names, selectedNames, autoDS, customTitle)
            try
                if nargin < 9 || isempty(autoDS)
                    autoDS = max(1, ceil(length(xAll) / 500));
                end
                ds = autoDS;
                x = xAll(1:ds:end);
                % Determine which variables to plot based on selection
                if nargin < 8 || isempty(selectedNames)
                    idx = 1:numel(names);
                    namesSel = names;
                else
                    % Normalize selection to cellstr and map to indices preserving order
                    if isstring(selectedNames)
                        namesSel = cellstr(selectedNames);
                        namesSel = namesSel(:)';
                    elseif ischar(selectedNames)
                        namesSel = {selectedNames};
                    elseif iscell(selectedNames)
                        % Convert any strings inside cell to char, preserve order
                        try
                            namesSel = cellfun(@char, selectedNames, 'UniformOutput', false);
                        catch
                            namesSel = selectedNames;
                        end
                        namesSel = namesSel(:)';
                    else
                        namesSel = names;
                    end
                    idx = [];
                    for k = 1:numel(namesSel)
                        j = find(strcmp(names, namesSel{k}), 1, 'first');
                        if ~isempty(j)
                            idx(end+1) = j; %#ok<AGROW>
                        end
                    end
                    if isempty(idx)
                        idx = 1:numel(names);
                        namesSel = names;
                    end
                end
                y = yAll(1:ds:end, idx);
                cla(ax);
                hold(ax,'on');
                switch styleDrop.Value
                    case 'lines'
                        plot(ax, x, y, 'LineWidth', 1.2);
                    case 'dots'
                        plot(ax, x, y, 'LineStyle','none','Marker','o','MarkerSize',3);
                    case 'line+markers'
                        plot(ax, x, y, '-o','LineWidth',1.0,'MarkerSize',3);
                end
                xlabel(ax, 'Time'); ylabel(ax, 'Value');
                if nargin >= 10 && ~isempty(customTitle)
                    title(ax, customTitle);
                else
                    title(ax, 'Time Series');
                end
                legend(ax, namesSel, 'Location', 'eastoutside');
                xlim(ax, [x(1) x(end)]);
                try
                    if numel(x) > 1
                        span = x(end) - x(1);
                        if span > 0
                            step = 10^floor(log10(span/8));
                            ticks = x(1):step:x(end);
                            xticks(ax, ticks);
                        end
                    end
                    xtickformat(ax, '%.0f');
                catch
                end
                if ~isempty(infoLbl) && isvalid(infoLbl)
                    infoLbl.Text = sprintf('Displaying ~%d of %d points (ds=%d), vars=%d/%d', numel(x), numel(xAll), ds, numel(idx), numel(names));
                end
                hold(ax,'off');
            catch
            end
        end

        % Function to auto-adjust Y-limits when X-limits change (zooming/panning)
        function autoAdjustYLimits(ax)
            try
                if isempty(ax) || ~isvalid(ax) || isempty(ax.Children)
                    return;
                end
                
                % Get current X-limits
                xlims = xlim(ax);
                
                % For each line in the plot, find min/max in visible range
                yMin = inf;
                yMax = -inf;
                hasData = false;
                
                for i = 1:length(ax.Children)
                    if isa(ax.Children(i), 'matlab.graphics.chart.primitive.Line')
                        xData = ax.Children(i).XData;
                        yData = ax.Children(i).YData;
                        
                        if isempty(xData) || isempty(yData)
                            continue;
                        end
                        
                        % Only consider points in current X-range
                        validIdx = xData >= xlims(1) & xData <= xlims(2);
                        if any(validIdx)
                            yMin = min(yMin, min(yData(validIdx)));
                            yMax = max(yMax, max(yData(validIdx)));
                            hasData = true;
                        end
                    end
                end
                
                % Only update if we have valid data
                if hasData && yMax > yMin
                    % Add 10% padding
                    yRange = yMax - yMin;
                    padding = yRange * 0.1;
                    ylim(ax, [yMin-padding, yMax+padding]);
                end
                
            catch ME
                % Silently handle any errors
                disp(['Error updating Y-limits: ' ME.message]);
            end
        end
        
        function cancelDialog(app, d)
            try
                setappdata(d,'cancelled',true);
            catch
            end
            try
                uiresume(d);
            catch
            end
        end

        function openVariableSelector(app, parentFig, names, xAll, yAll, ax, styleDrop, infoLbl, autoDS, varargin)
            % Create separate variable selection window for many variables
            try
                varFig = uifigure('Name', 'Select Variables', 'Position', [100 200 300 400], 'WindowStyle', 'modal');
                gl = uigridlayout(varFig, [3 1]); gl.RowHeight = {'fit', '1x', 'fit'};
                
                % Instructions
                instrLbl = uilabel(gl, 'Text', 'Select variables to display (Ctrl+click for multiple):');
                instrLbl.Layout.Row = 1; instrLbl.Layout.Column = 1;
                
                % Variable list
                varList = uilistbox(gl, 'Items', names, 'Multiselect', 'on', 'Value', names);
                try
                    varList.FontSize = 10; % smaller font for long lists
                catch
                end
                varList.Layout.Row = 2; varList.Layout.Column = 1;
                
                % Buttons
                btnPanel = uipanel(gl);
                btnPanel.Layout.Row = 3; btnPanel.Layout.Column = 1;
                btnGL = uigridlayout(btnPanel, [1 3]); btnGL.ColumnWidth = {'1x', 'fit', 'fit'};
                
                selectAllBtn = uibutton(btnGL, 'Text', 'Select All', 'ButtonPushedFcn', @(~,~) set(varList, 'Value', names));
                selectAllBtn.Layout.Row = 1; selectAllBtn.Layout.Column = 2;
                
                % Parse optional args for compatibility
                useViewMeasures = false;
                customTitle = '';
                try
                    if numel(varargin) >= 1 && ~isempty(varargin{1})
                        useViewMeasures = varargin{1};
                    end
                    if numel(varargin) >= 2 && ~isempty(varargin{2})
                        customTitle = varargin{2};
                    end
                catch
                end
                applyBtn = uibutton(btnGL, 'Text', 'Apply', 'ButtonPushedFcn', @(~,~) app.applyVariableSelection(varFig, varList, names, xAll, yAll, ax, styleDrop, infoLbl, autoDS, useViewMeasures, customTitle));
                applyBtn.Layout.Row = 1; applyBtn.Layout.Column = 3;
                
            catch ME
                try delete(varFig); catch, end
                uialert(parentFig, ['Error opening variable selector: ' ME.message], 'Error', 'Icon', 'error');
            end
        end

        function applyVariableSelection(app, varFig, varList, names, xAll, yAll, ax, styleDrop, infoLbl, autoDS, useViewMeasures, customTitle)
            try
                selectedVars = varList.Value;
                if isempty(selectedVars)
                    selectedVars = names;
                end
                % Update the plot according to context
                if exist('useViewMeasures','var') && useViewMeasures
                    if ~exist('customTitle','var') || isempty(customTitle)
                        customTitle = '';
                    end
                    app.replotViewMeasures(ax, styleDrop, infoLbl, xAll, yAll, names, selectedVars, autoDS, customTitle);
                    % Ensure style changes replot immediately with this selection
                    try
                        styleDrop.ValueChangedFcn = @(~,~) app.replotViewMeasures(ax, styleDrop, infoLbl, xAll, yAll, names, selectedVars, autoDS, customTitle);
                    catch
                    end
                else
                    app.replotPreview(ax, styleDrop, infoLbl, xAll, yAll, names, selectedVars, autoDS);
                    % Ensure style changes replot immediately with this selection
                    try
                        styleDrop.ValueChangedFcn = @(~,~) app.replotPreview(ax, styleDrop, infoLbl, xAll, yAll, names, selectedVars, autoDS);
                    catch
                    end
                end
                delete(varFig);
            catch ME
                uialert(varFig, ['Error applying selection: ' ME.message], 'Error', 'Icon', 'error');
            end
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.Name = 'Time Series Analysis - Causality & Correlation Measures';

            % Create LoadtimeseriesButton
            app.LoadtimeseriesButton = uibutton(app.UIFigure, 'push');
            app.LoadtimeseriesButton.ButtonPushedFcn = createCallbackFcn(app, @LoadtimeseriesButtonPushed, true);
            app.LoadtimeseriesButton.Position = [9 389 103 23];
            app.LoadtimeseriesButton.Text = 'Load time series';
            app.LoadtimeseriesButton.Tooltip = 'Load time series data from .txt files (supports multiple selections)';

            % Create SortbynameButton
            app.SortbynameButton = uibutton(app.UIFigure, 'push');
            app.SortbynameButton.ButtonPushedFcn = createCallbackFcn(app, @SortbynameButtonPushed, true);
            app.SortbynameButton.Position = [129 186 86 23];
            app.SortbynameButton.Text = 'Sort by name';
            app.SortbynameButton.Tooltip = 'Sort loaded time series alphabetically';

            % Create DeleteButton
            app.DeleteButton = uibutton(app.UIFigure, 'push');
            app.DeleteButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteButtonPushed, true);
            app.DeleteButton.Position = [230 186 62 23];
            app.DeleteButton.Text = 'Delete';
            app.DeleteButton.Tooltip = 'Delete selected time series from the list';

            % Create ExitButton
            app.ExitButton = uibutton(app.UIFigure, 'push');
            app.ExitButton.ButtonPushedFcn = createCallbackFcn(app, @ExitButtonPushed, true);
            app.ExitButton.Position = [514 74 100 23];
            app.ExitButton.Text = 'Exit';

            % Create HelpButton
            app.HelpButton = uibutton(app.UIFigure, 'push');
            app.HelpButton.ButtonPushedFcn = createCallbackFcn(app, @HelpButtonPushed, true);
            app.HelpButton.Position = [514 31 100 23];
            app.HelpButton.Text = 'Help';

            % Create SelectrunmeasuresButton
            app.SelectrunmeasuresButton = uibutton(app.UIFigure, 'push');
            app.SelectrunmeasuresButton.ButtonPushedFcn = createCallbackFcn(app, @SelectrunmeasuresButtonPushed, true);
            app.SelectrunmeasuresButton.Position = [313 389 125 23];
            app.SelectrunmeasuresButton.Text = 'Select/run measures';
            app.SelectrunmeasuresButton.Tooltip = 'Choose and compute causality/correlation measures';

            % Create savemeasuresButton
            app.savemeasuresButton = uibutton(app.UIFigure, 'push');
            app.savemeasuresButton.ButtonPushedFcn = createCallbackFcn(app, @savemeasuresButtonPushed, true);
            app.savemeasuresButton.Position = [325 357 100 23];
            app.savemeasuresButton.Text = 'save measures';
            app.savemeasuresButton.Tooltip = 'Export computed measures to a text file';

            % Create ViewmeasuresButton
            app.ViewmeasuresButton = uibutton(app.UIFigure, 'push');
            app.ViewmeasuresButton.ButtonPushedFcn = createCallbackFcn(app, @ViewmeasuresButtonPushed, true);
            app.ViewmeasuresButton.Position = [325 327 100 23];
            app.ViewmeasuresButton.Text = 'View measures';
            app.ViewmeasuresButton.Tooltip = 'Display heatmaps, networks, and visualizations of results';

            % Create ShowMatricesButton
            app.ShowMatricesButton = uibutton(app.UIFigure, 'push');
            app.ShowMatricesButton.ButtonPushedFcn = createCallbackFcn(app, @ShowMatricesButtonPushed, true);
            app.ShowMatricesButton.Position = [325 297 100 23];
            app.ShowMatricesButton.Text = 'Show matrices';
            app.ShowMatricesButton.Tooltip = 'View raw measure matrices as tables';

            % Create CurrentlistoftimeseriesListBoxLabel
            app.CurrentlistoftimeseriesListBoxLabel = uilabel(app.UIFigure);
            app.CurrentlistoftimeseriesListBoxLabel.HorizontalAlignment = 'right';
            app.CurrentlistoftimeseriesListBoxLabel.Position = [141 439 138 22];
            app.CurrentlistoftimeseriesListBoxLabel.Text = 'Current list of time series';

            % Create CurrentlistoftimeseriesListBox with ValueChangedFcn and multi-select
            app.CurrentlistoftimeseriesListBox = uilistbox(app.UIFigure);
            app.CurrentlistoftimeseriesListBox.Items = {'empty'};
            app.CurrentlistoftimeseriesListBox.Position = [129 222 163 218];
            app.CurrentlistoftimeseriesListBox.Value = 'empty';
            app.CurrentlistoftimeseriesListBox.Multiselect = 'on';
            app.CurrentlistoftimeseriesListBox.ValueChangedFcn = createCallbackFcn(app, @CurrentlistoftimeseriesListBoxValueChanged, true);

            % Create CurrentlistofmeasuresListBoxLabel
            app.CurrentlistofmeasuresListBoxLabel = uilabel(app.UIFigure);
            app.CurrentlistofmeasuresListBoxLabel.HorizontalAlignment = 'right';
            app.CurrentlistofmeasuresListBoxLabel.Position = [470 439 132 22];
            app.CurrentlistofmeasuresListBoxLabel.Text = 'Current list of measures';

            % Create CurrentlistofmeasuresListBox
            app.CurrentlistofmeasuresListBox = uilistbox(app.UIFigure);
            app.CurrentlistofmeasuresListBox.Items = {'empty'};
            app.CurrentlistofmeasuresListBox.Position = [452 242 163 198];
            app.CurrentlistofmeasuresListBox.Value = 'empty';
            app.CurrentlistofmeasuresListBox.Multiselect = 'on';

            % Create DeleteMeasuresButton
            app.DeleteMeasuresButton = uibutton(app.UIFigure, 'push');
            app.DeleteMeasuresButton.ButtonPushedFcn = createCallbackFcn(app, @DeleteMeasuresButtonPushed, true);
            app.DeleteMeasuresButton.Position = [452 195 100 22];
            app.DeleteMeasuresButton.Text = 'Delete';
            app.DeleteMeasuresButton.Tooltip = 'Remove selected measures from memory';

            % Create PreviewTimeSeriesButton
            app.PreviewTimeSeriesButton = uibutton(app.UIFigure, 'push');
            app.PreviewTimeSeriesButton.ButtonPushedFcn = createCallbackFcn(app, @PreviewTimeSeriesButtonPushed, true);
            app.PreviewTimeSeriesButton.Position = [300 20 150 30];
            app.PreviewTimeSeriesButton.Text = 'Preview Time Series';
            app.PreviewTimeSeriesButton.Tooltip = 'Plot and inspect the currently loaded time series';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)
        % Construct app
        function app = app1
            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)
            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end

        % Method to update measure results
        function updateMeasureResults(app, results)
            app.MeasureResults = results;
            app.updateMeasuresList();
            
            % Don't automatically show visualizations when measures are calculated
            % Only show them when View measures button is clicked
            % if isfield(results, 'MI')
            %     app.updateMIVisualization();
            % end
            % if isfield(results, 'GC')
            %     app.updateGCVisualization();
            % end
        end

        % Function to update measures list
        function updateMeasuresList(app)
            measures = {};
            
            % Check for Mutual Information results
            if isfield(app.MeasureResults, 'MI')
                measures{end+1} = 'Mutual Information';
            end
            
            % Check for Cross Correlation results
            if isfield(app.MeasureResults, 'CC')
                measures{end+1} = 'Cross Correlation';
            end
            
            % Check for Granger Causality results
            if isfield(app.MeasureResults, 'GC')
                measures{end+1} = 'Granger Causality';
            end
            
            % CDMI removed
            
            % Check for Transfer Entropy results
            if isfield(app.MeasureResults, 'TE')
                measures{end+1} = 'Transfer Entropy';
            end
            
            if isempty(measures)
                measures = {'No measures computed'};
            end
            
            app.CurrentlistofmeasuresListBox.Items = measures;
        end
        
        % Function to update Transfer Entropy visualization
        function updateTEVisualization(app)
            % Visualize Transfer Entropy matrix as a heatmap and table
            if ~isfield(app.MeasureResults, 'TE') || isempty(app.MeasureResults.TE)
                uialert(app.UIFigure, 'No Transfer Entropy results to display.', 'No Data');
                return;
            end
            teMatrix = app.MeasureResults.TE;
            % Normalize TE matrix for visualization
            minVal = min(teMatrix(:));
            maxVal = max(teMatrix(:));
            if maxVal > minVal
                teMatrixNorm = (teMatrix - minVal) / (maxVal - minVal);
            else
                teMatrixNorm = teMatrix; % All values are equal
            end
            % Prepare variable names for table headers
            varNames = [];
            varNames = app.getMeasureVarNames(size(teMatrixNorm, 1));
            % Create a figure with a uitable and heatmap
            f = figure('Name', 'Transfer Entropy Matrix', 'NumberTitle', 'off', 'Position', [100 100 700 450]);
            t = uitable(f, 'Data', round(teMatrixNorm, 3), 'ColumnName', varNames, 'RowName', varNames, 'Units', 'normalized', 'Position', [0 0.5 1 0.5]);
            ax = axes('Parent', f, 'Position', [0.08 0.08 0.84 0.34]);
            imagesc(ax, teMatrixNorm);
            colorbar(ax);
            title(ax, 'Transfer Entropy between Variables (Normalized)');
            set(ax, 'XTick', 1:length(varNames), 'XTickLabel', varNames, 'YTick', 1:length(varNames), 'YTickLabel', varNames);
            xlabel(ax, 'To Variable'); ylabel(ax, 'From Variable');
        end
        
        % Update the current list of measures in the main app
        function updateCurrentMeasuresList(app)
            measures = {};
            
            % Check for Mutual Information results
            if isfield(app.MeasureResults, 'MI') && ~isempty(app.MeasureResults.MI)
                measures{end+1} = 'Mutual Information';
            end
            
            % Check for Cross Correlation results
            if isfield(app.MeasureResults, 'CC') && ~isempty(app.MeasureResults.CC)
                measures{end+1} = 'Cross Correlation';
            end
            
            % Check for Granger Causality results
            if isfield(app.MeasureResults, 'GC') && ~isempty(app.MeasureResults.GC)
                measures{end+1} = 'Granger Causality';
            end
            
            % CDMI removed
            
            % Check for Transfer Entropy results
            if isfield(app.MeasureResults, 'TE') && ~isempty(app.MeasureResults.TE)
                measures{end+1} = 'Transfer Entropy';
            end
            
            % Check for Partial Transfer Entropy results
            if isfield(app.MeasureResults, 'PTE') && ~isempty(app.MeasureResults.PTE)
                measures{end+1} = 'Partial Transfer Entropy';
            end
            
            % Check for Conditional Granger Causality Index results
            if isfield(app.MeasureResults, 'CGCI') && ~isempty(app.MeasureResults.CGCI)
                measures{end+1} = 'CGCI';
            end
            
            if isempty(measures)
                measures = {'No measures calculated'};
            end
            
            app.CurrentlistofmeasuresListBox.Items = measures;
        end
    end

    methods (Access = private)
        function bringAppToFront(app)
            try
                if isprop(app.UIFigure, 'WindowState')
                    app.UIFigure.WindowState = 'normal';
                end
                app.UIFigure.Visible = 'on';
                drawnow;
                figure(app.UIFigure);
            catch
            end
        end
    end

    methods (Access = private)
        % Helper: resolve variable names for the loaded data, excluding the
        % Time column, with a Var1..VarN fallback when names are unavailable.
        function varNames = getMeasureVarNames(app, nVars)
            varNames = {};
            data = app.LoadedTimeSeriesData;
            if istable(data)
                allNames = data.Properties.VariableNames;
                if ~isempty(allNames) && strcmpi(allNames{1}, 'Time')
                    allNames = allNames(2:end);
                end
                if numel(allNames) == nVars
                    varNames = allNames;
                end
            end
            if isempty(varNames)
                varNames = arrayfun(@(i) sprintf('Var%d', i), 1:nVars, 'UniformOutput', false);
            end
        end
        function arrangeFigures(app, figHandles)
            try
                % Arrange figures vertically without overlap
                scr = get(0,'ScreenSize');
                screenW = scr(3); screenH = scr(4);
                margin = 40; % pixels
                figW = min(800, screenW - 2*margin);
                figH = min(420, floor((screenH - 2*margin) / max(1, numel(figHandles))));
                % Center horizontally
                x = floor((screenW - figW) / 2);
                % Nudge down a bit so top figure isn't off-screen
                topShift = 80; % pixels
                yTop = screenH - margin - figH - topShift;
                for i = 1:numel(figHandles)
                    posY = yTop - (i-1)*(figH + 10);
                    if posY < margin
                        posY = margin;
                    end
                    try
                        set(figHandles(i), 'Position', [x posY figW figH]);
                    catch
                    end
                end
            catch
            end
        end
        % Button pushed function: ShowMatricesButton
        function ShowMatricesButtonPushed(app, event)
            try
                if isempty(app.MeasureResults)
                    uialert(app.UIFigure, 'No measures have been computed yet. Please run some measures first.', 'No Measures', 'Icon', 'error');
                    return;
                end
                % --- Show tables/heatmaps on demand ---
                if isfield(app.MeasureResults, 'MI') && ~isempty(app.MeasureResults.MI)
                    app.showMITableAndPlot();
                end
                % CDMI removed
                if isfield(app.MeasureResults, 'TE') && ~isempty(app.MeasureResults.TE)
                    teMatrix = app.MeasureResults.TE;
                    % Sanitize off-diagonal NaNs -> 0 and alert
                    [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(teMatrix);
                    if nNaNOff > 0
                        app.alertNaNs('Transfer Entropy', nNaNOff, Mclean);
                    end
                    varNames = app.getMeasureVarNames(size(Mclean, 1));
                    f = uifigure('Name', 'Transfer Entropy Table', 'Position', [100 100 600 400]);
                    uit = uitable(f, 'Data', app.matrixToTableData(Mclean, 3), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                end
                if isfield(app.MeasureResults, 'CC') && ~isempty(app.MeasureResults.CC)
                    ccMatrix = app.MeasureResults.CC;
                    varNames = app.getMeasureVarNames(size(ccMatrix, 1));
                    % Significance-filter the CC matrix: zero out non-significant
                    % correlations (p >= alpha). Show Matrices is the filtered view;
                    % View Measures shows the raw r-values.
                    ccFiltered = ccMatrix;
                    titleSuffix = '';
                    if isfield(app.MeasureResults, 'CC_sig') && ~isempty(app.MeasureResults.CC_sig) ...
                            && isequal(size(app.MeasureResults.CC_sig), size(ccMatrix))
                        sigMask = logical(app.MeasureResults.CC_sig);
                        ccFiltered(~sigMask) = 0;
                        try
                            if isfield(app.MeasureResults, 'CC_alpha') && ~isempty(app.MeasureResults.CC_alpha)
                                titleSuffix = sprintf(' (significant only, alpha=%.3f)', app.MeasureResults.CC_alpha);
                            else
                                titleSuffix = ' (significant only)';
                            end
                        catch
                            titleSuffix = ' (significant only)';
                        end
                    end
                    f = uifigure('Name', ['Cross-Correlation Table' titleSuffix], 'Position', [100 200 600 400]);
                    ccFiltered(1:size(ccFiltered,1)+1:end) = NaN;
                    uit = uitable(f, 'Data', app.matrixToTableData(ccFiltered, 3), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                end
                if isfield(app.MeasureResults, 'PTE') && ~isempty(app.MeasureResults.PTE)
                    pteMatrix = app.MeasureResults.PTE;
                    % Sanitize off-diagonal NaNs -> 0 and alert
                    [Mclean, nNaNOff] = app.sanitizeMeasureMatrix(pteMatrix);
                    if nNaNOff > 0
                        app.alertNaNs('Partial Transfer Entropy', nNaNOff, Mclean);
                    end
                    % Show the raw PTE values (not normalized), diagonal empty
                    varNames = app.getMeasureVarNames(size(Mclean, 1));
                    f = uifigure('Name', 'Partial Transfer Entropy Table', 'Position', [100 300 600 400]);
                    uit = uitable(f, 'Data', app.matrixToTableData(Mclean, 3), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                end
                if isfield(app.MeasureResults, 'GC') && ~isempty(app.MeasureResults.GC)
                    gcMatrix = app.MeasureResults.GC;
                    varNames = app.getMeasureVarNames(size(gcMatrix, 1));
                    fTableRaw = uifigure('Name', 'Granger Causality Index Table', 'Position', [100 400 600 400]);
                    gcShow = gcMatrix; gcShow(1:size(gcShow,1)+1:end) = NaN;
                    uitRaw = uitable(fTableRaw, 'Data', app.matrixToTableData(gcShow, 4), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                    % If p-values available, show them in a separate table
                    gcTestOn = isfield(app.MeasureResults, 'GC_maketest') && app.MeasureResults.GC_maketest;
                    if gcTestOn && isfield(app.MeasureResults, 'GC_p') && ~isempty(app.MeasureResults.GC_p)
                        pMat = app.MeasureResults.GC_p;
                        fP = uifigure('Name', 'Granger Causality p-values (F-test)', 'Position', [720 400 600 400]);
                        pShow = pMat; pShow(1:size(pShow,1)+1:end) = NaN;
                        uitP = uitable(fP, 'Data', app.matrixToTableData(pShow, 4), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                    end
                end
                if isfield(app.MeasureResults, 'CGCI') && ~isempty(app.MeasureResults.CGCI)
                    cgciMatrix = app.MeasureResults.CGCI;
                    varNames = app.getMeasureVarNames(size(cgciMatrix, 1));
                    f = uifigure('Name', 'Conditional Granger Causality Index Table', 'Position', [100 100 600 400]);
                    cgShow = cgciMatrix; cgShow(1:size(cgShow,1)+1:end) = NaN;
                    uit = uitable(f, 'Data', app.matrixToTableData(cgShow, 4), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                    cgciTestOn = isfield(app.MeasureResults, 'CGCI_maketest') && app.MeasureResults.CGCI_maketest;
                    if cgciTestOn && isfield(app.MeasureResults, 'CGCI_p') && ~isempty(app.MeasureResults.CGCI_p)
                        pMat = app.MeasureResults.CGCI_p;
                        fP = uifigure('Name', 'CGCI p-values (F-test)', 'Position', [720 100 600 400]);
                        pShow = pMat; pShow(1:size(pShow,1)+1:end) = NaN;
                        uitP = uitable(fP, 'Data', app.matrixToTableData(pShow, 4), 'ColumnName', varNames, 'RowName', varNames, 'Position', [25 60 550 320]);
                    end
                end
            catch ME
                uialert(app.UIFigure, ['Error showing matrices: ' ME.message], 'Error', 'Icon', 'error');
            end
        end

        % Button pushed function: DeleteMeasuresButton
        function DeleteMeasuresButtonPushed(app, event)
            try
                % Check if measures exist
                if isempty(app.MeasureResults)
                    uialert(app.UIFigure, 'No measures to delete.', 'No Measures', 'Icon', 'error');
                    return;
                end
                
                % Get selected measures
                selectedMeasures = app.CurrentlistofmeasuresListBox.Value;
                
                if isempty(selectedMeasures) || (ischar(selectedMeasures) && strcmp(selectedMeasures, 'empty'))
                    uialert(app.UIFigure, 'Please select measures to delete.', 'No Selection', 'Icon', 'error');
                    return;
                end
                
                % Convert to cell array if single selection
                if ischar(selectedMeasures)
                    selectedMeasures = {selectedMeasures};
                end
                
                % Confirm deletion
                if length(selectedMeasures) == 1
                    confirmMsg = ['Are you sure you want to delete "' selectedMeasures{1} '"?'];
                else
                    confirmMsg = ['Are you sure you want to delete ' num2str(length(selectedMeasures)) ' selected measures?'];
                end
                
                choice = uiconfirm(app.UIFigure, confirmMsg, 'Confirm Deletion', ...
                    'Options', {'Yes', 'No'}, 'DefaultOption', 2, 'CancelOption', 2);
                
                if strcmp(choice, 'No')
                    return;
                end
                
                % Delete selected measures from MeasureResults
                for i = 1:length(selectedMeasures)
                    measure = selectedMeasures{i};
                    if strcmp(measure, 'Mutual Information') && isfield(app.MeasureResults, 'MI')
                        app.MeasureResults = rmfield(app.MeasureResults, 'MI');
                    elseif strcmp(measure, 'Cross Correlation') && isfield(app.MeasureResults, 'CC')
                        app.MeasureResults = rmfield(app.MeasureResults, 'CC');
                    elseif strcmp(measure, 'Granger Causality') && isfield(app.MeasureResults, 'GC')
                        app.MeasureResults = rmfield(app.MeasureResults, 'GC');
                        if isfield(app.MeasureResults, 'GC_p')
                            app.MeasureResults = rmfield(app.MeasureResults, 'GC_p');
                        end
                    elseif strcmp(measure, 'Transfer Entropy') && isfield(app.MeasureResults, 'TE')
                        app.MeasureResults = rmfield(app.MeasureResults, 'TE');
                    elseif strcmp(measure, 'Partial Transfer Entropy') && isfield(app.MeasureResults, 'PTE')
                        app.MeasureResults = rmfield(app.MeasureResults, 'PTE');
                    elseif strcmp(measure, 'CGCI') && isfield(app.MeasureResults, 'CGCI')
                        app.MeasureResults = rmfield(app.MeasureResults, 'CGCI');
                        if isfield(app.MeasureResults, 'CGCI_p')
                            app.MeasureResults = rmfield(app.MeasureResults, 'CGCI_p');
                        end
                    end
                end
                
                % Update the measures list display
                app.updateCurrentMeasuresList();
                
                % Notify user
                if length(selectedMeasures) == 1
                    uialert(app.UIFigure, 'Measure deleted successfully.', 'Success', 'Icon', 'success');
                else
                    uialert(app.UIFigure, [num2str(length(selectedMeasures)) ' measures deleted successfully.'], 'Success', 'Icon', 'success');
                end
                
            catch ME
                uialert(app.UIFigure, ['Error deleting measures: ' ME.message], 'Error', 'Icon', 'error');
            end
        end
        
        % Show significance heatmap with binary colormap (1=grey, 0=black) and X on diagonal
        function showSignificanceHeatmap(app, sigMatrix, varNames, titleStr)
            try
                pos = app.getNextWindowPosition();
                f = figure('Name', titleStr, 'NumberTitle', 'off', 'Position', pos);
                imagesc(sigMatrix);
                colormap([0 0 0; 0.7 0.7 0.7]); % Black for 0, Grey for 1
                colorbar('Ticks', [0, 1], 'TickLabels', {'Non-significant', 'Significant'});
                
                % Set axis labels
                nVars = length(varNames);
                if nVars > 30
                    % Hide tick labels for large matrices to avoid clutter
                    set(gca, 'XTick', [], 'XTickLabel', []);
                    set(gca, 'YTick', [], 'YTickLabel', []);
                else
                    set(gca, 'XTick', 1:nVars, 'XTickLabel', varNames);
                    set(gca, 'YTick', 1:nVars, 'YTickLabel', varNames);
                    % Rotate x-axis labels if needed
                    if nVars > 5
                        xtickangle(45);
                    end
                end
                
                title(titleStr, 'Interpreter', 'none');
                axis equal tight;
                
                % Add text annotations showing 0/1 values; draw X on diagonal
                [rows, cols] = size(sigMatrix);
                for i = 1:rows
                    for j = 1:cols
                        if i == j
                            text(j, i, 'X', 'HorizontalAlignment', 'center', 'Color', 'red', 'FontWeight', 'bold');
                        else
                            if sigMatrix(i,j) == 1
                                text(j, i, '1', 'HorizontalAlignment', 'center', 'Color', 'black', 'FontWeight', 'bold');
                            else
                                text(j, i, '0', 'HorizontalAlignment', 'center', 'Color', 'white', 'FontWeight', 'bold');
                            end
                        end
                    end
                end
                
            catch ME
                disp(['Error creating significance heatmap: ' ME.message]);
            end
        end
    end
end