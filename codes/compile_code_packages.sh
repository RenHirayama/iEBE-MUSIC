#!/usr/bin/env bash

Green='\033[0;32m'
NC='\033[0m'

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
cd "${repo_root}"

CCFlag=${1:-gcc}
CXXFlag=${2:-g++}
FCFlag=${3:-}

if [ -z "${FCFlag}" ]; then
    if command -v gfortran >/dev/null 2>&1; then
        FCFlag="$(command -v gfortran)"
    else
        candidate_fc="/lustre/hyihp/rhirayam/.local/micromamba/envs/fortran-env/bin/x86_64-conda-linux-gnu-gfortran"
        if [ -x "${candidate_fc}" ]; then
            FCFlag="${candidate_fc}"
        else
            FCFlag="gfortran"
        fi
    fi
fi

fftw_root="${FFTW_ROOT:-${repo_root}/third_party/fftw-install}"
hdf5_root="${HDF5_ROOT:-${repo_root}/third_party/hdf5-install}"

if [ -d "${fftw_root}" ] && [ -f "${fftw_root}/include/fftw3.h" ] && [ -f "${fftw_root}/lib/libfftw3.so" ]; then
    export FFTW_ROOT="${fftw_root}"
    export FFTW_DIR="${fftw_root}"
    export FFTW_INC="${fftw_root}/include"
    export FFTW_INCLUDE_DIRS="${fftw_root}/include"
    export FFTW_LIBRARY_DIRS="${fftw_root}/lib"
    export FFTW_LIBRARIES="-lfftw3 -lfftw3_threads -lfftw3_omp"
    export CMAKE_PREFIX_PATH="${fftw_root}:${CMAKE_PREFIX_PATH:-}"
    export PKG_CONFIG_PATH="${fftw_root}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="${fftw_root}/lib:${LD_LIBRARY_PATH:-}"
    export LIBRARY_PATH="${fftw_root}/lib:${LIBRARY_PATH:-}"
    export CPATH="${fftw_root}/include:${CPATH:-}"
    export C_INCLUDE_PATH="${fftw_root}/include:${C_INCLUDE_PATH:-}"
    export CPLUS_INCLUDE_PATH="${fftw_root}/include:${CPLUS_INCLUDE_PATH:-}"
else
    echo -e "${Green}FFTW not found in ${fftw_root}; if you installed it elsewhere, export FFTW_ROOT and rerun.${NC}"
fi

if [ -d "${hdf5_root}" ] && [ -f "${hdf5_root}/include/hdf5.h" ] && [ -f "${hdf5_root}/lib/libhdf5.so" ]; then
    export HDF5_ROOT="${hdf5_root}"
    export HDF5_DIR="${hdf5_root}"
    export HDF5_C_ROOT="${hdf5_root}"
    export CMAKE_PREFIX_PATH="${hdf5_root}:${CMAKE_PREFIX_PATH:-}"
    export PKG_CONFIG_PATH="${hdf5_root}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
    export LD_LIBRARY_PATH="${hdf5_root}/lib:${LD_LIBRARY_PATH:-}"
    export LIBRARY_PATH="${hdf5_root}/lib:${LIBRARY_PATH:-}"
    export CPATH="${hdf5_root}/include:${CPATH:-}"
    export C_INCLUDE_PATH="${hdf5_root}/include:${C_INCLUDE_PATH:-}"
    export CPLUS_INCLUDE_PATH="${hdf5_root}/include:${CPLUS_INCLUDE_PATH:-}"
else
    echo -e "${Green}HDF5 not found in ${hdf5_root}; if you installed it elsewhere, export HDF5_ROOT and rerun.${NC}"
fi

machine="$(uname -s)"
case "${machine}" in
    Linux*)     number_of_cores=`nproc --all`;;
    Darwin*)    number_of_cores=`sysctl -n hw.ncpu`;;
    *)          number_of_cores=1;;
esac
number_of_cores_to_compile=$(( ${number_of_cores} > 10 ? 10 : ${number_of_cores} ))

# compile 3dMCGlauber
echo -e "${Green}compile 3dMCGlauber ... ${NC}"
(
    cd 3dMCGlauber_code
    ./get_LHAPDF.sh
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake .. -Dlink_with_lib=OFF
    make -j${number_of_cores_to_compile}
    make install
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi

# compile IPGlasma
echo -e "${Green}compile IPGlasma ... ${NC}"
(
    cd ipglasma_code
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake .. -DdisableMPI=ON
    make -j${number_of_cores_to_compile}
    make install
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi

# compile KoMPoST
echo -e "${Green}compile KoMPoST ... ${NC}"
(
    cd kompost_code
    CXX=${CXXFlag} make
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi

# compile MUSIC
echo -e "${Green}compile MUSIC ... ${NC}"
(
    cd MUSIC_code
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake .. -Dlink_with_lib=OFF
    make -j${number_of_cores_to_compile}
    make install
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
mkdir -p MUSIC
cp MUSIC_code/example_inputfiles/IPGlasma_2D/music_input_mode_2 MUSIC/
cp MUSIC_code/utilities/sweeper.sh MUSIC/
(cd MUSIC; mkdir -p initial)

# compile photonEmission_hydroInterface
echo -e "${Green}compile photonEmission_hydroInterface ... ${NC}"
(
    cd photonEmission_hydroInterface_code
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake ..
    make -j${number_of_cores_to_compile}
    make install
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi

# download iSS particle sampler
echo -e "${Green}compile iSS ... ${NC}"
(
    cd iSS_code
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake .. -Dlink_with_lib=OFF
    make -j${number_of_cores_to_compile}
    make install
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi

# download UrQMD afterburner
echo -e "${Green}compile UrQMD ... ${NC}"
(
    cd urqmd_code
    FC=${FCFlag} make -j${number_of_cores_to_compile}
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
mkdir -p osc2u
cp urqmd_code/osc2u/osc2u.e osc2u/
mkdir -p urqmd
cp urqmd_code/urqmd/runqmd.sh urqmd/
cp urqmd_code/urqmd/uqmd.burner urqmd/


# download hadronic afterner
echo -e "${Green}compile hadronic afterburner toolkit ... ${NC}"
(
    cd hadronic_afterburner_toolkit_code
    rm -fr build
    mkdir -p build
    cd build
    CC=${CCFlag} CXX=${CXXFlag} cmake .. -Dlink_with_lib=OFF
    make -j${number_of_cores_to_compile}
    make install
    cd ../ebe_scripts
    ${CXXFlag} convert_to_binary.cpp -lz -o convert_to_binary.e
    mv convert_to_binary.e ../
    ${CXXFlag} concatenate_binary_files.cpp -lz -o concatenate_binary_files.e
    mv concatenate_binary_files.e ../
)
status=$?
if [ $status -ne 0 ]; then
    exit $status
fi
mkdir -p hadronic_afterburner_toolkit
cp hadronic_afterburner_toolkit_code/convert_to_binary.e hadronic_afterburner_toolkit/
cp hadronic_afterburner_toolkit_code/concatenate_binary_files.e hadronic_afterburner_toolkit/
cp hadronic_afterburner_toolkit_code/parameters.dat hadronic_afterburner_toolkit/
cp hadronic_afterburner_toolkit_code/ebe_scripts/average_event_HBT_correlation_function.py hadronic_afterburner_toolkit/

# expose the built tree under codes/ so generate_jobs.py can copy it into a working directory
mkdir -p "${repo_root}/codes"
for d in \
    3dMCGlauber_code \
    ipglasma_code \
    kompost_code \
    MUSIC_code \
    MUSIC \
    photonEmission_hydroInterface_code \
    iSS_code \
    urqmd_code \
    osc2u \
    urqmd \
    hadronic_afterburner_toolkit_code \
    hadronic_afterburner_toolkit; do
    if [ -e "${repo_root}/${d}" ] || [ -L "${repo_root}/${d}" ]; then
        ln -sfn "../${d}" "${repo_root}/codes/${d}"
    fi
done

# Also keep a root-level copy for the single-node workflow if those directories exist.
for d in MUSIC osc2u urqmd hadronic_afterburner_toolkit; do
    if [ -d "${repo_root}/${d}" ] && [ ! -e "${repo_root}/codes/${d}" ]; then
        ln -sfn "../${d}" "${repo_root}/codes/${d}"
    fi
done
