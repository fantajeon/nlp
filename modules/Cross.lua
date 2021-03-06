local Cross, parent = torch.class('nn.Cross', 'nn.Module')

function Cross:__init(coreModule, inModule, outModule)
   parent.__init(self)
   --self.output
   --self.gradInput
   --self.concatedInput
   self.coreModule = coreModule -- composition
   self.inModule = inModule -- representation of word
   self.outModule = outModule -- A nn module for classification
   self.gradIn = {} -- grads from inMoudle
   self.gradOut = {} -- grads from outMoudle
   self.gradCore = {} -- grads from coreMoudle
   --self.predTag
end

function Cross:updateOutput(input)

   -- concat the input with inModule's output
   --print("The input of Cross`")
   --print(input)
   local inOutput = self.inModule:getOutput() -- the input from inModule
   self.concatedInput = torch.Tensor(input:size()[1]+inOutput:size()[1])
   self.concatedInput:sub(1,input:size()[1]):copy(input)
   self.concatedInput:sub(input:size()[1]+1,input:size()[1]+inOutput:size()[1]):copy(inOutput)
   -- get the output from core module and give it to self.
   self.output = self.coreModule:forward(self.concatedInput)
   -- transfer output to outModule
   --@TODO split
   self.outModule:forward(self.output)
   --print(inOutput)
   --io.read()
   --self.outModule:forward(inOutput)
   --print("The output of Cross`")
   --print(self.output)
   -- return the output of coreModule
   return self.output
end

function Cross:updateGradInput(input, gradOutput)
   local inOutput = self.inModule:getOutput() 
   -- get the gradients( weight and input ) from outModule
   self.outModule:backward(self.output)
   local outGradInput = self.outModule:getGradInput()
   self.gradOut = self.outModule:getGradWeight()
   -- add the gradOutputs together
   local sumedGradOutput = gradOutput + outGradInput
   -- get the gradInput from coreModule
   local coreGradInput = self.coreModule:backward(self.concatedInput, sumedGradOutput)
   -- separate the gradInput two parts: one for inModule one for real gradInput
   local inGradOutput = coreGradInput:sub(input:size()[1]+1,input:size()[1]+inOutput:size()[1])
   --local inGradOutput = outGradInput
   self.gradInput = coreGradInput:sub(1,input:size()[1])
   -- pass the gradInput to inModule and get the gradWeight from inModule
   self.gradIn = self.inModule:getGradWeight(inGradOutput)
   --print(self.gradIn[1])
   --io.read()
   -- return real gradInput
   return self.gradInput
end

function Cross:accGradParameters(input, gradOutput, scale)
   -- just get the gradWeights from core
   self.gradCore = self.coreModule:getGradWeight()
end

function Cross:getGradParameters()
   return {self.gradIn,  self.gradCore, self.gradOut}
end

-- we do not need to accumulate parameters when sharing
Cross.sharedAccUpdateGradParameters = Cross.accUpdateGradParameters
