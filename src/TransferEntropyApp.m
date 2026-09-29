classdef TransferEntropyApp < matlab.apps.AppBase
	properties (Access = public)
		UIFigure matlab.ui.Figure
		NeighborsSpinner matlab.ui.control.Spinner
		NeighborsLabel matlab.ui.control.Label
		HorizonSpinner matlab.ui.control.Spinner
		HorizonLabel matlab.ui.control.Label
		EmbeddingSpinner matlab.ui.control.Spinner
		EmbeddingLabel matlab.ui.control.Label
		LagSpinner matlab.ui.control.Spinner
		LagLabel matlab.ui.control.Label
		OKButton matlab.ui.control.Button
		CancelButton matlab.ui.control.Button
		ParentApp % Reference to secondApp
	end
	methods (Access = public)
		function app = TransferEntropyApp(parentApp)
			if nargin > 0
				app.ParentApp = parentApp;
			end
			createComponents(app);
			registerApp(app, app.UIFigure);
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
			app.UIFigure = uifigure('Visible','off');
			app.UIFigure.Position = [300 300 360 260];
			app.UIFigure.Name = 'Transfer Entropy Parameters';
			% Neighbors
			app.NeighborsLabel = uilabel(app.UIFigure);
			app.NeighborsLabel.Position = [30 200 160 22];
			app.NeighborsLabel.Text = 'Neighbors (k):';
			app.NeighborsSpinner = uispinner(app.UIFigure);
			app.NeighborsSpinner.Position = [200 200 120 22];
			app.NeighborsSpinner.Limits = [2 100];
			app.NeighborsSpinner.Step = 1;
			app.NeighborsSpinner.Value = pickDefault(app,'TENeighbors',5);
			% Horizon T
			app.HorizonLabel = uilabel(app.UIFigure);
			app.HorizonLabel.Position = [30 165 160 22];
			app.HorizonLabel.Text = 'Prediction horizon (T):';
			app.HorizonSpinner = uispinner(app.UIFigure);
			app.HorizonSpinner.Position = [200 165 120 22];
			app.HorizonSpinner.Limits = [1 10];
			app.HorizonSpinner.Step = 1;
			app.HorizonSpinner.Value = pickDefault(app,'TET',1);
			% Embedding m
			app.EmbeddingLabel = uilabel(app.UIFigure);
			app.EmbeddingLabel.Position = [30 130 160 22];
			app.EmbeddingLabel.Text = 'Embedding (m):';
			app.EmbeddingSpinner = uispinner(app.UIFigure);
			app.EmbeddingSpinner.Position = [200 130 120 22];
			app.EmbeddingSpinner.Limits = [1 10];
			app.EmbeddingSpinner.Step = 1;
			app.EmbeddingSpinner.Value = pickDefault(app,'TEEmbedding',2);
			% Lag tau
			app.LagLabel = uilabel(app.UIFigure);
			app.LagLabel.Position = [30 95 160 22];
			app.LagLabel.Text = 'Lag (tau):';
			app.LagSpinner = uispinner(app.UIFigure);
			app.LagSpinner.Position = [200 95 120 22];
			app.LagSpinner.Limits = [1 50];
			app.LagSpinner.Step = 1;
			app.LagSpinner.Value = pickDefault(app,'TEDelay',1);
			% Buttons
			app.OKButton = uibutton(app.UIFigure,'push');
			app.OKButton.Position = [70 35 100 28];
			app.OKButton.Text = 'OK';
			app.OKButton.ButtonPushedFcn = @(~,~) onOK(app);
			app.CancelButton = uibutton(app.UIFigure,'push');
			app.CancelButton.Position = [190 35 100 28];
			app.CancelButton.Text = 'Cancel';
			app.CancelButton.ButtonPushedFcn = @(~,~) onCancel(app);
			app.UIFigure.Visible = 'on';
		end
		function v = pickDefault(app, name, fallback)
			v = fallback;
			try
				if ~isempty(app.ParentApp) && isprop(app.ParentApp, name)
					v = app.ParentApp.(name);
				end
			catch
			end
		end
		function onOK(app)
			try
				if ~isempty(app.ParentApp)
					app.ParentApp.TENeighbors = app.NeighborsSpinner.Value;
					app.ParentApp.TET = app.HorizonSpinner.Value;
					app.ParentApp.TEEmbedding = app.EmbeddingSpinner.Value;
					app.ParentApp.TEDelay = app.LagSpinner.Value;
					app.ParentApp.TESelected = true;
					if ismethod(app.ParentApp,'updateSelectedMeasuresList')
						app.ParentApp.updateSelectedMeasuresList();
					end
					if ~isempty(app.ParentApp.ParentApp) && isvalid(app.ParentApp.ParentApp)
						% propagate to app1 for visibility
						pp = app.ParentApp.ParentApp;
						if isprop(pp,'TEEmbedding'), pp.TEEmbedding = app.EmbeddingSpinner.Value; end
						if isprop(pp,'TEDelay'), pp.TEDelay = app.LagSpinner.Value; end
					end
				end
			catch
			end
			delete(app.UIFigure);
		end
		function onCancel(app)
			delete(app.UIFigure);
		end
	end
end


