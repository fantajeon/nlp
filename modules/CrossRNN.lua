require "nn"
local CrossRNN, parent = torch.class('nn.CrossRNN', 'nn.Module')

--build the RNN
function CrossRNN:__init(leftInputSize, rightInputSize, numTags, lookUpTable)
-- init all parameters
	--self.paraIn
	--torch.Tensor(outputSize, inputSize)
	self.paraOut = {weight = torch.randn(numTags, leftInputSize), bias = torch.randn(numTags)}
	self.paraCore = {weight = torch.randn(leftInputSize,rightInputSize + leftInputSize),
			bias = torch.randn(leftInputSize)};
	--print("the initial core weight:\n");
	--print(self.paraCore.weight);
	self.lookUpTable = lookUpTable;
	self.gradients = {};	-- grads from each cross module
	--self.initialNodeGrad		--The gradient of the initialNode (the returned valud of self.netWork:backward() )
	--self.netWork	--stores the network
	--self.netWorkDepth		--stores the layer number of the network
end

--we assume that each sentence comes with tags
function CrossRNN:initializeCross(word, index, tagId)
	inModule = nn.CrossWord(word, index);
	coreModule = nn.CrossCore(self.paraCore.weight, self.paraCore.bias);
	outModule = nn.CrossTag(self.paraOut.weight, self.paraOut.bias, tagId);
	CrossModule = nn.Cross(coreModule, inModule, outModule);
	return CrossModule;
end

--the sentence tuple contains the sentence information, index information and the tag informtion
--the buildNet function will be call in forward. You have to make sure that forward
--is called before backward. This function will not be called in backward again.
function CrossRNN:buildNet(sentenceTuple)
	self.netWorkDepth = #sentenceTuple.represents;
	self.netWork = nn.Sequential();
	for i = 1, self.netWorkDepth do
		currentWord = sentenceTuple.represents[i];
		currentIndex = sentenceTuple.index[i];
		currentTagId = sentenceTuple.tagsId[i];
		self.netWork:add(self:initializeCross(currentWord,currentIndex,currentTagId));
	end
end


function CrossRNN:forward(sentenceTuple, initialNode)
	-- unroll the RNN use sequentials
	self:buildNet(sentenceTuple);

	-- forward sequentialt for each of the cross module
	self.netWork:forward(initialNode);
	
	-- collect predicted tags
	predictedTags = {};
	for i = 1, self.netWorkDepth do
		predictedTags[i] = self.netWork:get(i).outModule:getPredTag();
	end
	
	-- return the predicted tags
	return predictedTags;
end

function CrossRNN:backward(sentenceTuple, initialNode)
	
	--!!!need to becareful here that the final output/gradOutput of the sentence is null
	local finalGradOutput = torch.zeros(initialNode:size());
	-- backward the sequential
	self.initialNodeGrad = self.netWork:backward(initialNode, finalGradOutput);

	-- collect gradParameters
	self.gradients = {};
	for i = 1, self.netWorkDepth do
		self.gradients[i] = self.netWork:get(i):getGradParameters();
	end
	--return gradients;
end

function CrossRNN:updateParameters(learningRates)
	--update the parameters
	local gradInWeightLength = self.gradients[1][1][1]:size();
	
	local gradCoreWeightLength = self.gradients[1][2][1]:size();
	local gradOutWeightLength = self.gradients[1][3][1]:size();

	local gradCoreBiasLength = #self.gradients[1][2][2];
	local gradOutBiasLength = #self.gradients[1][3][2];

	local gradInWeightSum = torch.Tensor(gradInWeightLength):fill(0);
	local gradCoreWeightSum = torch.Tensor(gradCoreWeightLength):fill(0);
	local gradOutWeightSum = torch.Tensor(gradOutWeightLength):fill(0);
	local gradCoreBiasSum = torch.Tensor(gradCoreBiasLength):fill(0);
	local gradOutBiasSum = torch.Tensor(gradOutBiasLength):fill(0);

	for i = 1, self.netWorkDepth do
		--call Roberts function to update word representation.
		--this is actually updating the InParas(words)
		wordIndex = self.netWork:get(i).inModule.inputIndex;
		wordGradient = torch.Tensor(1,50):copy(self.gradients[i][1][1]);
		self.lookUpTable:backwardUpdate(wordIndex, wordGradient, learningRates);

		--get the sum of all the gradients
		gradCoreWeightSum = gradCoreWeightSum + self.gradients[i][2][1];
		gradOutWeightSum = gradOutWeightSum + self.gradients[i][3][1];
		gradCoreBiasSum = gradCoreBiasSum + self.gradients[i][2][2];
		gradOutBiasSum = gradOutBiasSum + self.gradients[i][3][2];
	end

	--update the weight matrix parameters
	self.paraOut.weight = self.paraOut.weight - gradOutWeightSum * learningRates;
	self.paraOut.bias = self.paraOut.bias - gradOutBiasSum * learningRates;

	self.paraCore.weight = self.paraCore.weight - gradCoreWeightSum * learningRates;
	self.paraCore.bias = self.paraCore.bias - gradCoreBiasSum * learningRates;

	--update the initialNode
	print("The gradient of initialNode");
	print(self.initialNodeGrad);
	initialNodeGrad = torch.Tensor(1,50):copy(self.initialNodeGrad);
	self.lookUpTable:backwardUpdate('PADDING', initialNodeGrad, learningRates);
end
