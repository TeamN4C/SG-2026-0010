FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG VULN_COMMIT=12568ca8c8176785f5da005a5be17064c72c5536
ARG MODEL_URL=https://huggingface.co/ggml-org/test-model-stories260K/resolve/479896ec924af6d40fd419ab8f4d1eb2101de00d/stories260K-f32.gguf
ARG MODEL_SHA256=270cba1bd5109f42d03350f60406024560464db173c0e387d91f0426d3bd256d

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        cmake \
        curl \
        g++ \
        make \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
COPY . ./

RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Debug \
        -DCMAKE_C_FLAGS_DEBUG="-O1 -g3 -fno-omit-frame-pointer" \
        -DCMAKE_CXX_FLAGS_DEBUG="-O1 -g3 -fno-omit-frame-pointer" \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_NATIVE=OFF \
        -DGGML_SANITIZE_ADDRESS=ON \
        -DLLAMA_ALL_WARNINGS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=ON \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=ON \
        -DLLAMA_BUILD_WEBUI=OFF \
        -DLLAMA_OPENSSL=OFF \
        -DLLAMA_SANITIZE_ADDRESS=ON \
        -DLLAMA_BUILD_COMMIT="${VULN_COMMIT}" \
    && cmake --build build --target llama-server -j "$(nproc)"

RUN curl --fail --location --retry 3 \
        --output /stories260K-f32.gguf "${MODEL_URL}" \
    && echo "${MODEL_SHA256}  /stories260K-f32.gguf" | sha256sum --check --strict

FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libasan8 \
        libgomp1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /src/build/bin/llama-server /usr/local/bin/llama-server
COPY --from=builder /stories260K-f32.gguf /models/stories260K-f32.gguf

ENV ASAN_OPTIONS=abort_on_error=1:detect_leaks=0:halt_on_error=1:print_stacktrace=1:symbolize=1

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/llama-server"]
CMD ["-m", "/models/stories260K-f32.gguf", "--host", "0.0.0.0", "--port", "8080", "-c", "512", "-np", "1", "-t", "1", "--context-shift", "--no-warmup"]
