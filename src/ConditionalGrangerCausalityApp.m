classdef ConditionalGrangerCausalityApp < matlab.apps.AppBase
    properties (Access = public)
        UIFigure            matlab.ui.Figure
        OrderSpinner        matlab.ui.control.Spinner
        OrderSpinnerLabel   matlab.ui.control.Label
        MakeTestCheckBox    matlab.ui.control.CheckBox
        OKButton            matlab.ui.control.Button
        CancelButton        matlab.ui.control.Button
        ParentApp           % Reference to the parent app
    end

    methods (Access = private)
        function OKButtonPushed(app, ~)
            if ~isempty(app.ParentApp) && isvalid(app.ParentApp)
                app.ParentApp.CGCIOrder = app.OrderSpinner.Value;
                if isprop(app.ParentApp,'CGCIMakeTest')
                    app.ParentApp.CGCIMakeTest = app.MakeTestCheckBox.Value;
                end
                app.ParentApp.CGCISelected = true;
                app.ParentApp.updateSelectedMeasuresList();
            end
            delete(app.UIFigure);
        end
        function CancelButtonPushed(app, ~)
            delete(app.UIFigure);
        end
    end

    methods (Access = public)
        function app = ConditionalGrangerCausalityApp(parentApp)
            if nargin > 0
                app.ParentApp = parentApp;
            end
            createComponents(app)
            registerApp(app, app.UIFigure)
            if nargout == 0
                clear app
            end
        end
        function delete(app)
            delete(app.UIFigure)
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 340 180];
            app.UIFigure.Name = 'Conditional Granger Causality Index Parameters';

            % Title label
            titleLabel = uilabel(app.UIFigure);
            titleLabel.Text = 'Set Conditional Granger Causality Index Parameters';
            titleLabel.FontSize = 16;
            titleLabel.FontWeight = 'bold';
            titleLabel.Position = [20 140 300 28];

            % Help/description label
            helpLabel = uilabel(app.UIFigure);
            helpLabel.Text = 'Model order (p) controls how many past values are used. Allowed range: 1–10.';
            helpLabel.FontSize = 12;
            helpLabel.Position = [20 110 300 28];
            helpLabel.HorizontalAlignment = 'left';
            helpLabel.VerticalAlignment = 'top';

            % Model Order label
            app.OrderSpinnerLabel = uilabel(app.UIFigure);
            app.OrderSpinnerLabel.Position = [40 80 100 22];
            app.OrderSpinnerLabel.Text = 'Model Order (p):';
            app.OrderSpinnerLabel.FontSize = 12;

            % Model Order spinner
            app.OrderSpinner = uispinner(app.UIFigure);
            app.OrderSpinner.Position = [160 80 120 22];
            app.OrderSpinner.Value = 3;
            app.OrderSpinner.Limits = [1 10];
            app.OrderSpinner.FontSize = 12;

            % Compute p-values checkbox
            app.MakeTestCheckBox = uicheckbox(app.UIFigure);
            app.MakeTestCheckBox.Position = [40 55 240 22];
            app.MakeTestCheckBox.Text = 'Compute p-values (F-test)';
            app.MakeTestCheckBox.Value = false;

            % OK button
            app.OKButton = uibutton(app.UIFigure, 'push');
            app.OKButton.ButtonPushedFcn = createCallbackFcn(app, @OKButtonPushed, true);
            app.OKButton.Position = [60 30 100 28];
            app.OKButton.Text = 'OK';
            app.OKButton.FontSize = 12;

            % Cancel button
            app.CancelButton = uibutton(app.UIFigure, 'push');
            app.CancelButton.ButtonPushedFcn = createCallbackFcn(app, @CancelButtonPushed, true);
            app.CancelButton.Position = [180 30 100 28];
            app.CancelButton.Text = 'Cancel';
            app.CancelButton.FontSize = 12;

            app.UIFigure.Visible = 'on';
            % Initialize checkbox from parent if available
            try
                if ~isempty(app.ParentApp) && isprop(app.ParentApp,'CGCIMakeTest')
                    app.MakeTestCheckBox.Value = logical(app.ParentApp.CGCIMakeTest);
                end
            catch
            end
        end
    end
end 