function PTEM = PTEnneiAll(xallM,nnei,T,m,tau)
% PTEM = PTEnneiAll(xallM,nnei,T,m,tau)
% Partial Transfer Entropy for all pairs using nearest neighbors

[N,K] = size(xallM);
M = (m-1)*tau;
N1 = N-M-T;
PTEM = NaN(K,K);
if N1 <= 0 || K < 2
	return;
end

% Precompute lagged segments and futures for all variables
seg = cell(K,1);
fut = cell(K,1);
for k=1:K
	Xm = NaN*ones(N1,m);
	for im=1:m
		Xm(:,im) = xallM(M+1-(im-1)*tau:N-T-(im-1)*tau,k);
	end
	seg{k} = rangescale(Xm);
	Xf = NaN*ones(N1,T);
	for iT=1:T
		Xf(:,iT) = xallM(M+1+iT:N-T+iT,k);
	end
	fut{k} = rangescale(Xf);
end

psinnei = psi(nnei);

for iK=1:K
	for jK=1:K
		if iK == jK, continue; end
		drawnow limitrate; % Process UI events (e.g., Cancel click) between pairs
		xM = seg{iK};
		yM = seg{jK};
		xpreM = fut{iK};
		ypreM = fut{jK};
		% Build Z from remaining variables
		Zidx = setdiff(1:K, [iK jK]);
		L = numel(Zidx);
		if L == 0
			zzM = zeros(N1,0);
		else
			zzM = NaN*ones(N1, L*m);
			for ii=1:L
				zzM(:, (ii-1)*m + (1:m)) = seg{Zidx(ii)};
			end
		end
		% X->Y | Z
		condM = [yM zzM];
		xallnowM = [ypreM xM condM];
		[~, distsM] = annMaxquery(xallnowM', xallnowM', nnei+1);
		maxdistV = distsM(end,:)';
		n3V = nneighforgivenr(condM, maxdistV-ones(N1,1)*1e-10);
		n2V = nneighforgivenr([xM condM], maxdistV-ones(N1,1)*1e-10);
		n1V = nneighforgivenr([ypreM condM], maxdistV-ones(N1,1)*1e-10);
		psinowM = NaN*ones(N1,3);
		psinowM(:,1) = psi(n1V);
		psinowM(:,2) = psi(n2V);
		psinowM(:,3) = -psi(n3V);
		PTEM(iK,jK) = psinnei - mean(sum(psinowM,2));
	end
end

end


