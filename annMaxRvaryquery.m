function nnnidx = annMaxRvaryquery(Xr, Xq, R, k, varargin)
% nnnidx = annMaxRvaryquery(Xr, Xq, R, k, ...)
% Count neighbors within varying radii using max-norm (Chebyshev).
% Returns counts as 1 x nq.

% Try mex if available
try
	if exist('annMaxRvary_mex','file') == 3
		internal_opts = struct(); %#ok<NASGU>
		nnnidx = annMaxRvary_mex(Xr, Xq, R, internal_opts);
		nnnidx = double(nnnidx);
		return;
	end
catch
end

[d, n] = size(Xr); %#ok<ASGLU>
[d2, nq] = size(Xq);
if d2 ~= size(Xr,1)
	error('Dimension mismatch.');
end

% Exact KD-tree acceleration (Statistics and Machine Learning Toolbox).
% Counts neighbours within each point's own radius using the same max-norm
% (Chebyshev) distance, so results are identical to the brute force below.
% KD-trees only help in low dimensions, so for high-dimensional inputs
% (e.g. PTE conditioning vectors) we fall through to the vectorized brute
% force, which is about as fast as MATLAB allows there.
try
	if d <= 10 && exist('rangesearch','file') == 2 && exist('KDTreeSearcher','file') == 2
		selfQuery = isequal(Xr, Xq);
		Mdl = KDTreeSearcher(Xr', 'Distance', 'chebychev');
		Rv = R(:);
		nnnidx = zeros(1, nq);
		for j = 1:nq
			idxj = rangesearch(Mdl, Xq(:, j)', Rv(j));
			count = numel(idxj{1});
			if selfQuery
				count = count - 1; % exclude the point itself (distance 0)
				if count < 0, count = 0; end
			end
			nnnidx(j) = count;
		end
		return;
	end
catch
	% Fall through to pure MATLAB brute force on any error
end

% Pure MATLAB fallback
nnnidx = zeros(1, nq);
for j = 1:nq
	q = Xq(:, j)';
	% Chebyshev distance
	dv = max(abs(bsxfun(@minus, Xr', q)), [], 2);
	% Count within radius R(j), excluding self if Xr==Xq and dv==0
	count = sum(dv <= R(j));
	if Xr == Xq %#ok<BDSCA>
		count = count - 1;
		if count < 0, count = 0; end
	end
	nnnidx(j) = count;
end

end


