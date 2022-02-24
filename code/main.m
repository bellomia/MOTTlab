%% BSD 3-Clause License
% 
% Copyright (c) 2020-2022, Gabriele Bellomia
% All rights reserved.

clearvars; clc;
global DEBUG FAST

try
    pkg load signal     % GNU Octave option
end

%% INPUT: Physical Parameters 
U    = 0.09;            % On-site Repulsion
beta = inf;             % Inverse Temperature
D    = 1.0;             % Noninteracting half-bandwidth
latt = 'bcc';           % Noninteracting band-dispersion 
                        % ['bethe','cubic','square','chain'...]

%% INPUT: Boolean Flags
MottBIAS     = 0;       % Changes initial guess of gloc (strongly favours Mott phase)
ULINE        = 0;       % Takes and fixes the given beta value and performs a U-driven line
TLINE        = 0;       % Takes and fixes the given U value and performs a T-driven line
UTSCAN       = 0;       % Ignores both given U and beta values and builds a full phase diagram
SPECTRAL     = 0;       % Controls plotting of spectral functions
PLOT         = 0;       % Controls plotting of *all static* figures
GIF          = 0;       % Controls plotting of *animated* figures
UARRAY       = 1;       % Activates SLURM scaling of interaction values
TARRAY       = 0;       % Activates SLURM scaling of temperature values                    
DEBUG        = 0;       % Activates debug prints / plots / operations
FAST         = 1;       % Activates fast FFTW-based convolutions

%% INPUT: Control Parameters
mloop = 1000;           % Max number of DMFT iterations 
err   = 1e-5;           % Convergence threshold for self-consistency
mix   = 0.10;           % Mixing parameter for DMFT iterations (=1 means full update)
wres  = 2^15;           % Energy resolution in real-frequency axis
wcut  = 6.00;           % Energy cutoff in real-frequency axis
Umin  = 0.00;           % Hubbard U minimum value for phase diagrams
Ustep = 0.09;           % Hubbard U incremental step for phase diagrams
Umax  = 6.00;           % Hubbard U maximum value for phase diagrams
Tmin  = 1e-3;           % Temperature U minimum value for phase diagrams
Tstep = 1e-3;           % Temperature incremental step for phase diagrams
Tmax  = 5e-2;           % Temperature U maximum value for phase diagrams
dt    = 0.05;           % Frame duration in seconds (for GIF plotting)

%% SLURM-SCALING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

aID = str2double(getenv('SLURM_ARRAY_TASK_ID'));

if UARRAY
   U = U*aID;
end

if TARRAY
   beta = beta*aID;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

switch latt

    case {'square','cubic','bcc'}

        fprintf(2,'SLOW-RUN: %s lattice requires symbolic computations \n',latt);

    otherwise

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Init

% Frequency Values
w = linspace(-wcut,wcut,wres); 

% Initial guess for the local Green's function
if MottBIAS
   gloc_0 = 0; % no bath -> no Kondo resonance -> strong Mott bias :)
else
   gloc_0 = phys.gloc(w + 10^(-3)*1i,D,latt);
end

%% Workflows

if not( ULINE || TLINE || UTSCAN )
    %% Single (U,T) point
    fprintf('Single point evaluation @ U = %f, T = %f\n\n',U,1/beta); tic
    [gloc,sloc] = dmft_loop(gloc_0,w,U,beta,D,latt,mloop,mix,err);
    Z = phys.zetaweight(w,sloc);
    I = phys.luttinger(w,sloc,gloc);
    S = phys.strcorrel(w,sloc);
    if(PLOT && SPECTRAL)
        [DOS,SELF_ENERGY] = plot.spectral_frame(w,gloc,sloc,U,beta,D);
    end
    ET = [0,0,toc]; fmt = 'hh:mm:ss.SSS';
    fprintf('> %s < elapsed time\n\n',duration(ET,'format',fmt));
    writematrix(U,sprintf('U%f_HU.dat',U));
    writematrix(I,sprintf('U%f_IL.dat',U)); 
    writematrix(Z,sprintf('U%f_ZF.dat',U)); 
    writematrix(S,sprintf('U%f_SR.dat',U));
end

if ULINE
    %% U-driven MIT line [given T]
    fprintf('U-driven span @ T = %f\n\n',1/beta); tic
    clear('gloc','sloc','Z','I','S')
    Uvec = Umin:Ustep:Umax; NU = length(Uvec);
    for i = 1:NU 
        U = Uvec(i);
        fprintf('< U = %f\n',U);
        [gloc{i},sloc{i}] = dmft_loop(gloc_0,w,U,beta,D,latt,mloop,mix,err,'quiet');
        Z(i) = phys.zetaweight(w,sloc{i});
        I(i) = phys.luttinger(w,sloc{i},gloc{i});
        S(i) = phys.strcorrel(w,sloc{i});
    end
    if(PLOT)
        u_span = plot.Uline(Z,I,beta,Umin,Ustep,Umax,D);
    end
    if(GIF && SPECTRAL)
        plot.spectral_gif(w,gloc,sloc,Umin:Ustep:Umax,1/beta,D,dt);
    end
    ET = [0,0,toc]; fmt = 'hh:mm:ss.SSS';
    fprintf('> %s < elapsed time\n\n',duration(ET,'format',fmt));
end

if TLINE
    %% T-driven MIT line [given U]
    fprintf('T-driven span @ U = %f\n\n',U); tic
    clear('gloc','sloc','Z','I','S')
    Tvec = Tmin:Tstep:Tmax; NT = length(Tvec);
    for i = 1:NT 
        T = Tvec(i); beta = 1/T;
        fprintf('< T = %f\n',T);
        [gloc{i},sloc{i}] = dmft_loop(gloc_0,w,U,beta,D,latt,mloop,mix,err,'quiet');
        Z(i) = phys.zetaweight(w,sloc{i});
        I(i) = phys.luttinger(w,sloc{i},gloc{i});
        S(i) = phys.strcorrel(w,sloc{i});
    end
    if(PLOT)
        t_span = plot.Tline(Z,U,Tmin,Tstep,Tmax,D);
    end
    if(GIF && SPECTRAL)
        plot.spectral_gif(w,gloc,sloc,U,Tmin:Tstep:Tmax,D,dt);
    end
    ET = [0,0,toc]; fmt = 'hh:mm:ss.SSS';
    fprintf('> %s < elapsed time\n\n',duration(ET,'format',fmt));
end

if UTSCAN
    %% Full Phase-Diagram [U-driven]
    fprintf('Full phase diagram\n\n'); tic; 
    clear('gloc','sloc','Z','I','S')
    %restart_gloc = gloc_0;
    Tvec = Tmin:Tstep:Tmax; NT = length(Tvec);
    Uvec = Umin:Ustep:Umax; NU = length(Uvec);
    for i = 1:NT 
        T = Tvec(i); beta = 1/T;
        for j = 1:NU  
            U = Uvec(j);
            fprintf('< U = %f, T = %f\n',U, T);
            [gloc{i,j},sloc{i,j}] = dmft_loop(gloc_0,w,U,beta,D,latt,mloop,mix,err,'quiet');
            %restart_gloc = gloc{i,j};
            Z(i,j) = phys.zetaweight(w,sloc{i,j});
            I(i,j) = phys.luttinger(w,sloc{i,j},gloc{i,j});
            S(i,j) = phys.strcorrel(w,sloc{i,j});
        end
    end
    if(PLOT)
        phasemap = plot.phase_diagram(S,Umin,Ustep,Umax,Tmin,Tstep,Tmax,D);
    end
    ET = [0,0,toc]; fmt = 'hh:mm:ss.SSS';
    fprintf('> %s < elapsed time\n\n',duration(ET,'format',fmt));
end



