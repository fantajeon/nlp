#ifndef NLP_EMBEDDINGS_HPP_
#define NLP_EMBEDDINGS_HPP_

#include <cassert>

#include "nlp/kernels.hpp"
#include "nlp/tensor.hpp"
#include "opencl/cl.hpp"

namespace nlp {

using cl::CommandQueue;
using cl::Context;
using cl::Device;
using cl::Kernel;
using cl::NDRange;
using cl::NullRange;
using std::vector;

class Embeddings {
public:
  Embeddings(Context &context, vector<Device> &devices, CommandQueue &command_queue):
      command_queue_(command_queue),
      kernel_(BuildKernel(context, devices, "nlp/embeddings.cl", "Embeddings")) {}

  void operator ()(const Tensor<> &w, const Tensor<int> &x, Tensor<> &y) {
    assert(CL_SUCCESS == SetTensorArg(kernel_, 0, w));
    assert(CL_SUCCESS == SetTensorArg(kernel_, 1, x));
    assert(CL_SUCCESS == SetTensorArg(kernel_, 2, y));
    assert(CL_SUCCESS == command_queue_.enqueueNDRangeKernel(
        kernel_, NullRange, NDRange(y.shape.at(0), y.shape.at(1)), NullRange));
  }

private:
  CommandQueue &command_queue_;
  Kernel kernel_;
};

}  // namespace nlp

#endif  // NLP_EMBEDDINGS_HPP_