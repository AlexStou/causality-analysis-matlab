function TEM = TEnneiAll(xallM,nnei,T,m,tau)
% TEM = TEnneiAll(xallM,nnei,T,m,tau)
% Transfer Entropy matrix for all pairs using nearest neighbors

[N,K] = size(xallM);
M = (m-1)*tau;
N1 = N-M-T;
if N1 <= 0
	TEM = NaN(K,K);
	return;
end

TEM = NaN(K,K);

% Precompute X segments and futures for each variable
xSeg = cell(K,1);
xFut = cell(K,1);
for iK=1:K
	xMi = NaN*ones(N1,m);
	for im=1:m
		xMi(:,im) = xallM(M+1-(im-1)*tau:N-T-(im-1)*tau,iK);
	end
	xSeg{iK} = rangescale(xMi);
	XiF = NaN*ones(N1,T);
	for iT=1:T
		XiF(:,iT) = xallM(M+1+iT:N-T+iT,iK);
	end
	xFut{iK} = rangescale(XiF);
end

psinnei = psi(nnei);

for iK=1:K-1
	for jK=iK+1:K
		drawnow limitrate; % Process UI events (e.g., Cancel click) between pairs
		xM = xSeg{iK};
		yM = xSeg{jK};
		xpreM = xFut{iK};
		ypreM = xFut{jK};
		% X->Y
		xallnowM = [ypreM xM yM];
		[~, distsM] = annMaxquery(xallnowM', xallnowM', nnei+1);
		maxdistV = distsM(end,:)';
		n3V = nneighforgivenr(yM, maxdistV - ones(N1,1)*1e-10);
		n2V = nneighforgivenr([xM yM], maxdistV - ones(N1,1)*1e-10);
		n1V = nneighforgivenr([ypreM yM], maxdistV - ones(N1,1)*1e-10);
		psinowM = NaN*ones(N1,3);
		psinowM(:,1) = psi(n1V);
		psinowM(:,2) = psi(n2V);
		psinowM(:,3) = -psi(n3V);
		TEM(iK,jK) = psinnei - mean(sum(psinowM,2));
		% Y->X
		xallnowM = [xpreM yM xM];
		[~, distsM] = annMaxquery(xallnowM', xallnowM', nnei+1);
		maxdistV = distsM(end,:)';
		n3V = nneighforgivenr(xM, maxdistV - ones(N1,1)*1e-10);
		n2V = nneighforgivenr([yM xM], maxdistV - ones(N1,1)*1e-10);
		n1V = nneighforgivenr([xpreM xM], maxdistV - ones(N1,1)*1e-10);
		psinowM = NaN*ones(N1,3);
		psinowM(:,1) = psi(n1V);
		psinowM(:,2) = psi(n2V);
		psinowM(:,3) = -psi(n3V);
		TEM(jK,iK) = psinnei - mean(sum(psinowM,2));
	end
end

end


