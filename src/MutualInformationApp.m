classdef MutualInformationApp < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        BinsSpinner        matlab.ui.control.Spinner
        BinsSpinnerLabel   matlab.ui.control.Label
        BinsHintLabel      matlab.ui.control.Label
        LagsSpinner        matlab.ui.control.Spinner
        LagsSpinnerLabel   matlab.ui.control.Label
        OKButton           matlab.ui.control.Button
        CancelButton       matlab.ui.control.Button
    end

    properties (Access = public)
        ParentApp   % Reference to the calling app
        Bins = 10   % Default number of bins
        Lags = 1    % Default number of lags
    end

    methods (Access = private)

        % Value changed function: BinsSpinner
        function BinsSpinnerValueChanged(app, event)
            % Show/hide adaptive binning hint
            if app.BinsSpinner.Value == 0
                app.BinsHintLabel.Visible = 'on';
            else
                app.BinsHintLabel.Visible = 'off';
            end
        end

        % Button pushed function: OKButton
        function OKButtonPushed(app, event)
            try
                % Update the parent app (secondApp) with new values
                app.ParentApp.MIBins = app.BinsSpinner.Value;
                app.ParentApp.MILags = app.LagsSpinner.Value;
                app.ParentApp.MISelected = true;
                
                % Update the display in secondApp
                app.ParentApp.updateSelectedMeasuresList();
                
                % Also update the original app (app1) if it exists
                if ~isempty(app.ParentApp.ParentApp)
                    app.ParentApp.ParentApp.MIBins = app.BinsSpinner.Value;
                    app.ParentApp.ParentApp.MILags = app.LagsSpinner.Value;
                    
                    % Update the selected measures list in the parent app if the method exists
                    if ismethod(app.ParentApp.ParentApp, 'updateSelectedMeasuresList')
                        app.ParentApp.ParentApp.updateSelectedMeasuresList();
                    end
                end
                
                % Close the app without showing success message to avoid extra dialogs
                delete(app);
            catch ME
                % Show error message
                uialert(app.UIFigure, ['Error setting parameters: ' ME.message], 'Error', 'Icon', 'error');
            end
        end

        % Button pushed function: CancelButton
        function CancelButtonPushed(app, ~)
            % Just close the app without saving
            delete(app.UIFigure);
        end
    end

    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)
            % Create UIFigure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 300 220];
            app.UIFigure.Name = 'Mutual Information Parameters';

            % Create BinsSpinnerLabel
            app.BinsSpinnerLabel = uilabel(app.UIFigure);
            app.BinsSpinnerLabel.Position = [71 120 35 22];
            app.BinsSpinnerLabel.Text = 'Bins:';

            % Create BinsSpinner
            app.BinsSpinner = uispinner(app.UIFigure);
            app.BinsSpinner.Limits = [0 100];
            app.BinsSpinner.Value = app.Bins;
            app.BinsSpinner.ValueChangedFcn = createCallbackFcn(app, @BinsSpinnerValueChanged, true);
            app.BinsSpinner.Position = [121 120 100 22];

            % Create BinsHintLabel (shows adaptive binning formula when bins=0)
            app.BinsHintLabel = uilabel(app.UIFigure);
            app.BinsHintLabel.Position = [71 145 210 22];
            app.BinsHintLabel.Text = '(0 = Auto: √(n/5), n=data length)';
            app.BinsHintLabel.FontSize = 12;
            app.BinsHintLabel.FontColor = [0.5 0.5 0.5];
            if app.BinsSpinner.Value ~= 0
                app.BinsHintLabel.Visible = 'off';
            end

            % Create LagsSpinnerLabel
            app.LagsSpinnerLabel = uilabel(app.UIFigure);
            app.LagsSpinnerLabel.Position = [71 80 35 22];
            app.LagsSpinnerLabel.Text = 'Lags:';

            % Create LagsSpinner
            app.LagsSpinner = uispinner(app.UIFigure);
            app.LagsSpinner.Limits = [0 50];
            app.LagsSpinner.Value = app.Lags;
            app.LagsSpinner.Position = [121 80 100 22];

            % Create OKButton
            app.OKButton = uibutton(app.UIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [71 30 100 22];
            app.OKButton.Text = 'OK';

            % Create CancelButton
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [181 30 100 22];
            app.CancelButton.Text = 'Cancel';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    methods (Access = public)

        % Construct app
        function app = MutualInformationApp
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
    end
end 