function Im_2ndDiagram = SOPT(A0,f,U)
%% SOPT stands for Second Order Perturbation Theory:
%  it computes the imaginary part of the 2nd order diagram (bubble)
%
%% Input  
%
%  A0 : Noninteracting spectral function, A_0(\omega) -> real-value array
%  f  : Fermi-Dirac distribution, f(\omega) -> real-value array
%  U  : On-site interaction, U -> real scalar
%
%% Theoretical Background at:
%
%  http://www.physics.rutgers.edu/~haule/681/Perturbation.pdf
%
%% BSD 3-Clause License
%
%  Copyright (c) 2020, Gabriele Bellomia
%  All rights reserved.
                                                          global DEBUG FAST

    %% We take advantage of half-filling condition and discard A^-(\omega)
    Ap   = A0.*f;              % Occupied States Distribution: A^+(\omega)
  if FAST
    App  = math.fconv(Ap,Ap,'same');  % Optimized FFTW-based convolution
    Appp = math.fconv(Ap,App,'same'); % Optimized FFTW-based convolution
  else
    App  = conv(Ap,Ap,'same');        % Built-in vectorized convolution
    Appp = conv(Ap,App,'same');       % Built-in vectorized convolution      
  end
    pppA = flip(Appp);  % flip([1 2 3]) == [3 2 1]
    Im_2ndDiagram = -pi*U^2*(Appp + pppA);
  if DEBUG && FAST
    test = conv(Ap,Ap,'same');
    err1 = abs(norm(test-App)/norm(test));
    if err1 > 100*eps
       fprintf('Error on 1st convolution: %.16f \n',err1);
    end
    test = conv(Ap,test,'same');
    err2 = abs(norm(test-Appp)/norm(test));
    if err2 > 100*eps
       fprintf('Error on 2nd convolution: %.16f \n',err2);
    end
  end
end


