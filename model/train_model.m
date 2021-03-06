function [parameters] = train_model(parameters,f, ...
  ds,dlT0,dlX0,dlTB,dlXB,...
  miniBatchSize,numEpochs,executionEnvironment,...
  initialLearnRate,decayRate,options,verbose)

% Shuffle dataset
% ds = shuffle(ds);

% Used to verify termination condition
dlTXC = dlarray(cell2mat(ds.readall)','CB');
dlTC = dlTXC(1,:);
dlXC = dlTXC(2:end,:);

% Arrange points in a minibatch
mbq = minibatchqueue(ds, ...
    'MiniBatchSize',miniBatchSize, ...
    'MiniBatchFormat','BC', ...
    'OutputEnvironment',executionEnvironment);
  
% If training using a GPU, convert the initial and conditions to |gpuArray|.
if (executionEnvironment == "auto" && canUseGPU) || (executionEnvironment == "gpu")
    dlT0 = gpuArray(dlT0);
    dlX0 = gpuArray(dlX0);
    dlTB = gpuArray(dlTB);
    dlXB = gpuArray(dlXB);
end

% For each iteration:
% * Read a mini-batch of data from the mini-batch queue
% * Evaluate the model gradients and loss using the accelerated model gradients 
% and |dlfeval| functions.
% * Update the learning rate.
% * Update the learnable parameters using the |adamupdate| function.
% At the end of each epoch, update the training plot with the loss values.

% Initialize the parameters for the Adam solver.
averageGrad = [];
averageSqGrad = [];

% Accelerate the model gradients function using the |dlaccelerate| function. 
accfun_loss = dlaccelerate(@modelLoss);

% Initialize the training progress plot.
if verbose
  ht = figure('Position',[250 300 850 470]);
  C = colororder;
  lineLoss = animatedline('Color',C(2,:),'LineWidth',2);
  ylim([0 inf])
  xlabel("Iteration")
  ylabel("Loss")
  grid on
end

start = tic;
iteration = 0;
for epoch = 1:numEpochs
    reset(mbq);

    while hasdata(mbq)
        
        % Update iteration number
        iteration = iteration + 1;

        % Extract next minibatch
        dlTX = next(mbq);
        dlT = dlTX(1,:);
        dlX = dlTX(2:end,:);

        % Evaluate the model gradients and loss using dlfeval
        [gradients,loss,~] = dlfeval(accfun_loss,parameters,dlX,dlT,dlX0,dlT0,dlXB,dlTB,f,options);
        

        % Update learning rate
        learningRate = initialLearnRate / (1+decayRate*iteration);
        
        % Update the network parameters using the adamupdate function
        [parameters,averageGrad,averageSqGrad] = adamupdate(parameters,gradients,averageGrad, ...
            averageSqGrad,iteration,learningRate);       
        
        loss = double(gather(extractdata(loss)));
        D = duration(0,0,toc(start),'Format','hh:mm:ss');        
        if verbose
          % Plot training progress
          addpoints(lineLoss,iteration, loss);
          figure(ht)
          title("Epoch: " + epoch + ", Elapsed: " + string(D) + ", Learning rate: " + learningRate + ", Loss: " + loss)
          drawnow
        else
          disp("Epoch: " + epoch + ", Elapsed: " + string(D) + ", Learning rate: " + learningRate + ", Loss: " + loss)        
        end
    end 
    
    [~,~,solutionFound] = dlfeval(@modelLoss,parameters,dlXC,dlTC,dlX0,dlT0,dlXB,dlTB,f,options);
    
    % Break the cycle if a solution is found
    if solutionFound 
      disp('Solution found!')
      break
    end
end

end

