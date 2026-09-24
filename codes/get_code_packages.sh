#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
third_party_dir="${repo_root}/third_party"
mkdir -p "${third_party_dir}"

install_fftw() {
    local fftw_prefix="${repo_root}/third_party/fftw-install"
    if [ -f "${fftw_prefix}/include/fftw3.h" ] && [ -f "${fftw_prefix}/lib/libfftw3.so" ]; then
        echo "FFTW already installed at ${fftw_prefix}"
        return 0
    fi

    echo "Installing FFTW into ${fftw_prefix}"
    cd "${third_party_dir}"
    curl -L --fail -o fftw-3.3.10.tar.gz https://www.fftw.org/fftw-3.3.10.tar.gz
    rm -rf fftw-3.3.10 fftw-3.3.10.tar.gz.1
    tar -xzf fftw-3.3.10.tar.gz
    cd fftw-3.3.10
    ./configure --prefix="${fftw_prefix}" --enable-shared --enable-threads --enable-openmp --disable-fortran
    make -j"$(nproc --all 2>/dev/null || echo 4)"
    make install
}

install_hdf5() {
    local hdf5_prefix="${repo_root}/third_party/hdf5-install"
    if [ -f "${hdf5_prefix}/include/hdf5.h" ] && [ -f "${hdf5_prefix}/lib/libhdf5.so" ]; then
        echo "HDF5 already installed at ${hdf5_prefix}"
        return 0
    fi

    echo "Installing HDF5 into ${hdf5_prefix}"
    cd "${third_party_dir}"
    curl -L --fail -o hdf5-1.14.5.tar.gz https://codeload.github.com/HDFGroup/hdf5/tar.gz/refs/tags/hdf5-1.14.5
    rm -rf hdf5-hdf5-1.14.5 hdf5-build
    tar -xzf hdf5-1.14.5.tar.gz
    mkdir -p hdf5-build
    cd hdf5-build
    cmake ../hdf5-hdf5-1.14.5 \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${hdf5_prefix}" \
      -DBUILD_SHARED_LIBS=ON \
      -DHDF5_BUILD_CPP_LIB=ON \
      -DBUILD_TESTING=OFF
    make -j"$(nproc --all 2>/dev/null || echo 4)"
    make install
}

install_fortran_toolchain() {
    local micromamba_bin="${repo_root}/.local/bin/micromamba"
    local env_root="${repo_root}/.local/micromamba"
    local gfortran_bin="${env_root}/envs/fortran-env/bin/x86_64-conda-linux-gnu-gfortran"

    if command -v gfortran >/dev/null 2>&1; then
        echo "System gfortran already available: $(command -v gfortran)"
        return 0
    fi

    if [ -x "${gfortran_bin}" ]; then
        echo "Local gfortran already available at ${gfortran_bin}"
        return 0
    fi

    echo "Installing local Fortran toolchain via micromamba"
    mkdir -p "${repo_root}/.local/bin" "${env_root}"
    if [ ! -x "${micromamba_bin}" ]; then
        curl -Ls https://micro.mamba.pm/api/micromamba/linux-64/latest | \
          tar -xvj -C "${repo_root}/.local/bin" --strip-components=1 bin/micromamba
    fi
    MAMBA_ROOT_PREFIX="${env_root}" "${micromamba_bin}" create -y -n fortran-env -c conda-forge gfortran_linux-64
}

if [ ! -f "${repo_root}/third_party/fftw-install/include/fftw3.h" ] || [ ! -f "${repo_root}/third_party/fftw-install/lib/libfftw3.so" ]; then
    install_fftw
fi

if [ ! -f "${repo_root}/third_party/hdf5-install/include/hdf5.h" ] || [ ! -f "${repo_root}/third_party/hdf5-install/lib/libhdf5.so" ]; then
    install_hdf5
fi

if ! command -v gfortran >/dev/null 2>&1 && [ ! -x "${repo_root}/.local/micromamba/envs/fortran-env/bin/x86_64-conda-linux-gnu-gfortran" ]; then
    install_fortran_toolchain
fi

# download the code package

# download 3DMCGlauber
rm -fr 3dMCGlauber_code
git clone --depth=5 https://github.com/chunshen1987/3dMCGlauber 3dMCGlauber_code
(cd 3dMCGlauber_code; git checkout c5fb78113bc23cde601f854e0e92676672124dd9)
rm -fr 3dMCGlauber_code/.git

# download IPGlasma
rm -fr ipglasma_code
git clone --depth=1 https://github.com/chunshen1987/ipglasma -b ipglasma_jimwlk ipglasma_code
(cd ipglasma_code; git checkout 7cd9f37a38181fec85b71399ac7b46f233200a97)
rm -fr ipglasma_code/.git

# download KoMPoST
rm -fr kompost_code
git clone --depth=1 https://github.com/chunshen1987/KoMPoST kompost_code
(cd kompost_code; git checkout ad5fe9d3b26434bb1d5c29820499ef26808b5a47)
rm -fr kompost_code/.git

# download MUSIC
rm -fr MUSIC_code
git clone --depth=3 https://github.com/MUSIC-fluid/MUSIC -b chun_dev MUSIC_code
(cd MUSIC_code; git checkout e25e49363e92c269f61fe7b8ab4bf5368bcc6d23)
rm -fr MUSIC_code/.git

# download iSS particle sampler
rm -fr iSS_code
git clone --depth=3 https://github.com/chunshen1987/iSS -b dev iSS_code
(cd iSS_code; git checkout b612a8e425d3e1dfc2d2b71cd208df6810c783be)
rm -fr iSS_code/.git

# download photonEmission wrapper
rm -fr photonEmission_hydroInterface_code
git clone --depth=1 https://github.com/chunshen1987/photonEmission_hydroInterface photonEmission_hydroInterface_code
(cd photonEmission_hydroInterface_code; git checkout b80fb78c154cc9131162c8205615faffc86d6a49)
rm -fr photonEmission_hydroInterface_code/.git

# download UrQMD afterburner
rm -fr urqmd_code
git clone --depth=1 https://Chunshen1987@bitbucket.org/Chunshen1987/urqmd_afterburner.git urqmd_code
(cd urqmd_code; git checkout 704c886)
rm -fr urqmd_code/.git

# download hadronic afterner
rm -fr hadronic_afterburner_toolkit_code
git clone --depth=5 https://github.com/chunshen1987/hadronic_afterburner_toolkit -b main hadronic_afterburner_toolkit_code
(cd hadronic_afterburner_toolkit_code; git checkout e0cb8e5869bc6a8855f904d46d4c9e33a61db93a )
rm -fr hadronic_afterburner_toolkit_code/.git

# download nucleus configurations for 3D-Glauber
(cd 3dMCGlauber_code/tables; bash download_nucleusTables.sh;)
# download nucleus configurations for IP-Glasma
(cd ipglasma_code/nucleusConfigurations; bash download_nucleusTables.sh;)
# download essential EOS files for hydro simulations
(cd MUSIC_code/EOS; bash download_hotQCD.sh; bash download_Neos2D.sh bqs;)
