%% Example #5
% Pendulum with contracting and rotating trajectory domain.

clearvars
close all
clc

addpath ./functions
addpath ./model
addpath ./plot

rng(0) % for repeatability

%% Define FTS problem

% Time vector
t = (0:5e-2:2)';

% System
f = @odefun; 

% State dimension
nx = 2;

% Ellipsoidal domains
w = 0.1;
rot = @(t)[cos(w*2*pi*t) sin(w*2*pi*t); -sin(w*2*pi*t), cos(w*2*pi*t)]';
G = @(t)rot(t)*[2/pi^2*exp(0.5*t) 0; 0 0.1/pi^2*exp(2*t)]*rot(t)';
% G = @(t)[2/pi^2 0; 0 0.5/pi^2]*exp(0.4*t);
R = 4/pi^2 * eye(2);

plot_trajectories(t,R,G,nx,f)

%% Choose collocation points
NPC = 60000; % 50000
NPB = 100; % for each time sample
NP0 = 700;

% Total number of points
NP = NPC+NPB*numel(t)+NP0;

% Place collocation points
[TC,XC] = place_collocation_points_ellipse(t,G,NPC,nx);
[T0,X0] = place_initial_points_ellipse(t,R,NP0,nx);
[TB,XB] = place_boundary_points_ellipse(t,G,NPB,nx);

% Create datastore with collocation points (to be divided in minibatches)
ds = arrayDatastore([TC XC]);

% Convert the initial and boundary conditions to |dlarray|; all thee points 
% are used at each training iteration.
% Specify format with dimensions |'CB'| (channel, batch).
dlTB = dlarray(TB','CB');
dlXB = dlarray(XB','CB');

dlT0 = dlarray(T0','CB');
dlX0 = dlarray(X0','CB');


%% Define deep learning model

% Define a multilayer perceptron architecture.
numLayers = 5; % # hidden layers + 2 (in/out)
numNeurons = 32; 
numIn  = nx + 1; % state and time
numOut = 1;

parameters = initNetwork(numIn,numOut,numNeurons,numLayers);


%% Specify Training Options

% Epochs and minibatch size
numEpochs = 40;
numMiniBatches = 500; %500
miniBatchSize = round(NP/numMiniBatches);

% Specify ADAM optimization options.
initialLearnRate = 0.003; %0.003
decayRate = 0.00001;

% To train on a GPU if one is available, specify the execution environment "auto". 
executionEnvironment = "auto";

% Additional training parameters
options.wVdot     = 3;
options.wVbound   = 1;
options.wVt       = 0;
options.tolVbound = 1e-0;
options.tolVdot   = 1e-1;

% Debug options
verbose = 0;

%% Train model
parameters = train_model(parameters,f, ...
  ds,dlT0,dlX0,dlTB,dlXB,...
  miniBatchSize,numEpochs,executionEnvironment,...
  initialLearnRate,decayRate,options,verbose);

%% Validate and plot results
plot_collocation_points(t,R,G,T0,X0,TB,XB,TC,XC)

filename = 'E5_res.gif';
plot_results;

rmpath ./functions
rmpath ./model
rmpath ./plot



return



%% Plant
function xdot = odefun(~,x)
g = 9.81;
m = 0.15;
b = 0.1;
l = 0.5;

xdot = [x(2,:)
        -g/l*sin(x(1,:))-b/(m*l^2)*x(2,:)];
end
