// Macros for converting subscripts to linear index:
#define INDEX2D_R(m, n) (m)*(NY_R)+(n)
#define INDEX2D_MAT(m, n) (m)*({{NY_MATCOEFFS}})+(n)
#define INDEX3D_FIELDS(i, j, k) (i)*({{NY_FIELDS}})*({{NZ_FIELDS}})+(j)*({{NZ_FIELDS}})+(k)
#define INDEX4D_ID(p, i, j, k) (p)*({{NX_ID}})*({{NY_ID}})*({{NZ_ID}})+(i)*({{NY_ID}})*({{NZ_ID}})+(j)*({{NZ_ID}})+(k)
#define INDEX4D_PHI1(p, i, j, k) (p)*(NX_PHI1)*(NY_PHI1)*(NZ_PHI1)+(i)*(NY_PHI1)*(NZ_PHI1)+(j)*(NZ_PHI1)+(k)
#define INDEX4D_PHI2(p, i, j, k) (p)*(NX_PHI2)*(NY_PHI2)*(NZ_PHI2)+(i)*(NY_PHI2)*(NZ_PHI2)+(j)*(NZ_PHI2)+(k)

// material update coefficients to be declared in constant memory
__constant {{REAL}} updatecoeffsE[{{N_updatecoeffsE}}] = 
{
    {% for i in updateEVal %}
    {{i}},
    {% endfor %}
};

__constant {{REAL}} updatecoeffsH[{{N_updatecoeffsH}}] = 
{
    {% for i in updateHVal %}
    {{i}},
    {% endfor %}
};


__kernel void order1_xminus(int xs, int xf, int ys, int yf, int zs, int zf, int NX_PHI1, int NY_PHI1, int NZ_PHI1, int NX_PHI2, int NY_PHI2, int NZ_PHI2, int NY_R, __global const unsigned int* restrict ID, __global const {{REAL}}* restrict Ex, __global const {{REAL}}* restrict Ey, __global const {{REAL}}* restrict Ez, __global const {{REAL}}* restrict Hx, __global {{REAL}} *Hy, __global {{REAL}} *Hz, __global {{REAL}} *PHI1, __global {{REAL}} *PHI2, __global const {{REAL}}* restrict RA, __global const {{REAL}}* restrict RB, __global const {{REAL}}* restrict RE, __global const {{REAL}}* restrict RF, {{REAL}} d){
    //  This function updates the Hy and Hz field components for the xminus slab.
    //
    //  Args:
    //      xs, xf, ys, yf, zs, zf: Cell coordinates of PML slab
    //      NX_PHI, NY_PHI, NZ_PHI, NY_R: Dimensions of PHI1, PHI2, and R PML arrays
    //      ID, E, H: Access to ID and field component arrays
    //      Phi, RA, RB, RE, RF: Access to PML magnetic coefficient arrays
    //      d: Spatial discretisation, e.g. dx, dy or dz

    // Obtain the linear index corresponding to the current tREad
    int idx = get_global_id(2) * get_global_size(0) * get_global_size(1) + get_global_id(1) * get_global_size(0) + get_global_id(0);

    // Convert the linear index to subscripts for PML PHI1 (4D) arrays
    int p1 = idx / (NX_PHI1 * NY_PHI1 * NZ_PHI1);
    int i1 = (idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) / (NY_PHI1 * NZ_PHI1);
    int j1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) / NZ_PHI1;
    int k1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) % NZ_PHI1;

    // Convert the linear index to subscripts for PML PHI2 (4D) arrays
    int p2 = idx / (NX_PHI2 * NY_PHI2 * NZ_PHI2);
    int i2 = (idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) / (NY_PHI2 * NZ_PHI2);
    int j2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) / NZ_PHI2;
    int k2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) % NZ_PHI2;

    {{REAL}} RA01, RB0, RE0, RF0, dEy, dEz;
    {{REAL}} dx = d;
    int ii, jj, kk, materialHy, materialHz;
    int nx = xf - xs;
    int ny = yf - ys;
    int nz = zf - zs;

    if (p1 == 0 && i1 < nx && j1 < ny && k1 < nz) {
        // Subscripts for field arrays
        ii = xf - (i1 + 1);
        jj = j1 + ys;
        kk = k1 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,i1)] - 1;
        RB0 = RB[INDEX2D_R(0,i1)];
        RE0 = RE[INDEX2D_R(0,i1)];
        RF0 = RF[INDEX2D_R(0,i1)];

        // Hy
        materialHy = ID[INDEX4D_ID(4,ii,jj,kk)];
        dEz = (Ez[INDEX3D_FIELDS(ii+1,jj,kk)] - Ez[INDEX3D_FIELDS(ii,jj,kk)]) / dx;
        Hy[INDEX3D_FIELDS(ii,jj,kk)] = Hy[INDEX3D_FIELDS(ii,jj,kk)] + updatecoeffsH[INDEX2D_MAT(materialHy,4)] * (RA01 * dEz + RB0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)]);
        PHI1[INDEX4D_PHI1(0,i1,j1,k1)] = RE0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)] - RF0 * dEz;
    }

    if (p2 == 0 && i2 < nx && j2 < ny && k2 < nz) {
        // Subscripts for field arrays
        ii = xf - (i2 + 1);
        jj = j2 + ys;
        kk = k2 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,i2)] - 1;
        RB0 = RB[INDEX2D_R(0,i2)];
        RE0 = RE[INDEX2D_R(0,i2)];
        RF0 = RF[INDEX2D_R(0,i2)];

        // Hz
        materialHz = ID[INDEX4D_ID(5,ii,jj,kk)];
        dEy = (Ey[INDEX3D_FIELDS(ii+1,jj,kk)]  - Ey[INDEX3D_FIELDS(ii,jj,kk)]) / dx;
        Hz[INDEX3D_FIELDS(ii,jj,kk)] = Hz[INDEX3D_FIELDS(ii,jj,kk)] - updatecoeffsH[INDEX2D_MAT(materialHz,4)] * (RA01 * dEy + RB0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)]);
        PHI2[INDEX4D_PHI2(0,i2,j2,k2)] = RE0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)] - RF0 * dEy;
    }
}

__kernel void order1_xplus(int xs, int xf, int ys, int yf, int zs, int zf, int NX_PHI1, int NY_PHI1, int NZ_PHI1, int NX_PHI2, int NY_PHI2, int NZ_PHI2, int NY_R, __global const unsigned int* restrict ID, __global const {{REAL}}* restrict Ex, __global const {{REAL}}* restrict Ey, __global const {{REAL}}* restrict Ez, __global const {{REAL}}* restrict Hx, __global {{REAL}} *Hy, __global {{REAL}} *Hz, __global {{REAL}} *PHI1, __global {{REAL}} *PHI2, __global const {{REAL}}* restrict RA, __global const {{REAL}}* restrict RB, __global const {{REAL}}* restrict RE, __global const {{REAL}}* restrict RF, {{REAL}} d){
    //  This function updates the Hy and Hz field components for the xplus slab.
    //
    //  Args:
    //      xs, xf, ys, yf, zs, zf: Cell coordinates of PML slab
    //      NX_PHI, NY_PHI, NZ_PHI, NY_R: Dimensions of PHI1, PHI2, and R PML arrays
    //      ID, E, H: Access to ID and field component arrays
    //      Phi, RA, RB, RE, RF: Access to PML magnetic coefficient arrays
    //      d: Spatial discretisation, e.g. dx, dy or dz

    // Obtain the linear index corresponding to the current tREad
    int idx = get_global_id(2) * get_global_size(0) * get_global_size(1) + get_global_id(1) * get_global_size(0) + get_global_id(0);

    // Convert the linear index to subscripts for PML PHI1 (4D) arrays
    int p1 = idx / (NX_PHI1 * NY_PHI1 * NZ_PHI1);
    int i1 = (idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) / (NY_PHI1 * NZ_PHI1);
    int j1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) / NZ_PHI1;
    int k1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) % NZ_PHI1;

    // Convert the linear index to subscripts for PML PHI2 (4D) arrays
    int p2 = idx / (NX_PHI2 * NY_PHI2 * NZ_PHI2);
    int i2 = (idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) / (NY_PHI2 * NZ_PHI2);
    int j2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) / NZ_PHI2;
    int k2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) % NZ_PHI2;

    {{REAL}} RA01, RB0, RE0, RF0, dEy, dEz;
    {{REAL}} dx = d;
    int ii, jj, kk, materialHy, materialHz;
    int nx = xf - xs;
    int ny = yf - ys;
    int nz = zf - zs;

    if (p1 == 0 && i1 < nx && j1 < ny && k1 < nz) {
        // Subscripts for field arrays
        ii = i1 + xs;
        jj = j1 + ys;
        kk = k1 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,i1)] - 1;
        RB0 = RB[INDEX2D_R(0,i1)];
        RE0 = RE[INDEX2D_R(0,i1)];
        RF0 = RF[INDEX2D_R(0,i1)];

        // Hy
        materialHy = ID[INDEX4D_ID(4,ii,jj,kk)];
        dEz = (Ez[INDEX3D_FIELDS(ii+1,jj,kk)] - Ez[INDEX3D_FIELDS(ii,jj,kk)]) / dx;
        Hy[INDEX3D_FIELDS(ii,jj,kk)] = Hy[INDEX3D_FIELDS(ii,jj,kk)] + updatecoeffsH[INDEX2D_MAT(materialHy,4)] * (RA01 * dEz + RB0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)]);
        PHI1[INDEX4D_PHI1(0,i1,j1,k1)] = RE0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)] - RF0 * dEz;
    }

    if (p2 == 0 && i2 < nx && j2 < ny && k2 < nz) {
        // Subscripts for field arrays
        ii = i2 + xs;
        jj = j2 + ys;
        kk = k2 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,i2)] - 1;
        RB0 = RB[INDEX2D_R(0,i2)];
        RE0 = RE[INDEX2D_R(0,i2)];
        RF0 = RF[INDEX2D_R(0,i2)];

        // Hz
        materialHz = ID[INDEX4D_ID(5,ii,jj,kk)];
        dEy = (Ey[INDEX3D_FIELDS(ii+1,jj,kk)] - Ey[INDEX3D_FIELDS(ii,jj,kk)]) / dx;
        Hz[INDEX3D_FIELDS(ii,jj,kk)] = Hz[INDEX3D_FIELDS(ii,jj,kk)] - updatecoeffsH[INDEX2D_MAT(materialHz,4)] * (RA01 * dEy + RB0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)]);
        PHI2[INDEX4D_PHI2(0,i2,j2,k2)] = RE0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)] - RF0 * dEy;
    }
}

__kernel void order1_yminus(int xs, int xf, int ys, int yf, int zs, int zf, int NX_PHI1, int NY_PHI1, int NZ_PHI1, int NX_PHI2, int NY_PHI2, int NZ_PHI2, int NY_R, __global const unsigned int* restrict ID, __global const {{REAL}}* restrict Ex, __global const {{REAL}}* restrict Ey, __global const {{REAL}}* restrict Ez, __global {{REAL}} *Hx, __global const {{REAL}}* restrict Hy, __global {{REAL}} *Hz, __global {{REAL}} *PHI1, __global {{REAL}} *PHI2, __global const {{REAL}}* restrict RA, __global const {{REAL}}* restrict RB, __global const {{REAL}}* restrict RE, __global const {{REAL}}* restrict RF, {{REAL}} d){

    //  This function updates the Hx and Hz field components for the yminus slab.
    //
    //  Args:
    //      xs, xf, ys, yf, zs, zf: Cell coordinates of PML slab
    //      NX_PHI, NY_PHI, NZ_PHI, NY_R: Dimensions of PHI1, PHI2, and R PML arrays
    //      ID, E, H: Access to ID and field component arrays
    //      Phi, RA, RB, RE, RF: Access to PML magnetic coefficient arrays
    //      d: Spatial discretisation, e.g. dx, dy or dz

    // Obtain the linear index corresponding to the current tREad
    int idx = get_global_id(2) * get_global_size(0) * get_global_size(1) + get_global_id(1) * get_global_size(0) + get_global_id(0);

    // Convert the linear index to subscripts for PML PHI1 (4D) arrays
    int p1 = idx / (NX_PHI1 * NY_PHI1 * NZ_PHI1);
    int i1 = (idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) / (NY_PHI1 * NZ_PHI1);
    int j1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) / NZ_PHI1;
    int k1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) % NZ_PHI1;

    // Convert the linear index to subscripts for PML PHI2 (4D) arrays
    int p2 = idx / (NX_PHI2 * NY_PHI2 * NZ_PHI2);
    int i2 = (idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) / (NY_PHI2 * NZ_PHI2);
    int j2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) / NZ_PHI2;
    int k2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) % NZ_PHI2;

    {{REAL}} RA01, RB0, RE0, RF0, dEx, dEz;
    {{REAL}} dy = d;
    int ii, jj, kk, materialHx, materialHz;
    int nx = xf - xs;
    int ny = yf - ys;
    int nz = zf - zs;

    if (p1 == 0 && i1 < nx && j1 < ny && k1 < nz) {
        // Subscripts for field arrays
        ii = i1 + xs;
        jj = yf - (j1 + 1);
        kk = k1 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,j1)] - 1;
        RB0 = RB[INDEX2D_R(0,j1)];
        RE0 = RE[INDEX2D_R(0,j1)];
        RF0 = RF[INDEX2D_R(0,j1)];

        // Hx
        materialHx = ID[INDEX4D_ID(3,ii,jj,kk)];
        dEz = (Ez[INDEX3D_FIELDS(ii,jj+1,kk)] - Ez[INDEX3D_FIELDS(ii,jj,kk)]) / dy;
        Hx[INDEX3D_FIELDS(ii,jj,kk)] = Hx[INDEX3D_FIELDS(ii,jj,kk)] - updatecoeffsH[INDEX2D_MAT(materialHx,4)] * (RA01 * dEz + RB0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)]);
        PHI1[INDEX4D_PHI1(0,i1,j1,k1)] = RE0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)] - RF0 * dEz;
    }

    if (p2 == 0 && i2 < nx && j2 < ny && k2 < nz) {
        // Subscripts for field arrays
        ii = i2 + xs;
        jj = yf - (j2 + 1);
        kk = k2 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,j2)] - 1;
        RB0 = RB[INDEX2D_R(0,j2)];
        RE0 = RE[INDEX2D_R(0,j2)];
        RF0 = RF[INDEX2D_R(0,j2)];

        // Hz
        materialHz = ID[INDEX4D_ID(5,ii,jj,kk)];
        dEx = (Ex[INDEX3D_FIELDS(ii,jj+1,kk)] - Ex[INDEX3D_FIELDS(ii,jj,kk)]) / dy;
        Hz[INDEX3D_FIELDS(ii,jj,kk)] = Hz[INDEX3D_FIELDS(ii,jj,kk)] + updatecoeffsH[INDEX2D_MAT(materialHz,4)] * (RA01 * dEx + RB0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)]);
        PHI2[INDEX4D_PHI2(0,i2,j2,k2)] = RE0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)] - RF0 * dEx;
    }
}

__kernel void order1_yplus(int xs, int xf, int ys, int yf, int zs, int zf, int NX_PHI1, int NY_PHI1, int NZ_PHI1, int NX_PHI2, int NY_PHI2, int NZ_PHI2, int NY_R, __global const unsigned int* restrict ID, __global const {{REAL}}* restrict Ex, __global const {{REAL}}* restrict Ey, __global const {{REAL}}* restrict Ez, __global {{REAL}} *Hx, __global const {{REAL}}* restrict Hy, __global {{REAL}} *Hz, __global {{REAL}} *PHI1, __global {{REAL}} *PHI2, __global const {{REAL}}* restrict RA, __global const {{REAL}}* restrict RB, __global const {{REAL}}* restrict RE, __global const {{REAL}}* restrict RF, {{REAL}} d){

    //  This function updates the Hx and Hz field components for the yplus slab.
    //
    //  Args:
    //      xs, xf, ys, yf, zs, zf: Cell coordinates of PML slab
    //      NX_PHI, NY_PHI, NZ_PHI, NY_R: Dimensions of PHI1, PHI2, and R PML arrays
    //      ID, E, H: Access to ID and field component arrays
    //      Phi, RA, RB, RE, RF: Access to PML magnetic coefficient arrays
    //      d: Spatial discretisation, e.g. dx, dy or dz

    // Obtain the linear index corresponding to the current tREad
    int idx = get_global_id(2) * get_global_size(0) * get_global_size(1) + get_global_id(1) * get_global_size(0) + get_global_id(0);

    // Convert the linear index to subscripts for PML PHI1 (4D) arrays
    int p1 = idx / (NX_PHI1 * NY_PHI1 * NZ_PHI1);
    int i1 = (idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) / (NY_PHI1 * NZ_PHI1);
    int j1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) / NZ_PHI1;
    int k1 = ((idx % (NX_PHI1 * NY_PHI1 * NZ_PHI1)) % (NY_PHI1 * NZ_PHI1)) % NZ_PHI1;

    // Convert the linear index to subscripts for PML PHI2 (4D) arrays
    int p2 = idx / (NX_PHI2 * NY_PHI2 * NZ_PHI2);
    int i2 = (idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) / (NY_PHI2 * NZ_PHI2);
    int j2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) / NZ_PHI2;
    int k2 = ((idx % (NX_PHI2 * NY_PHI2 * NZ_PHI2)) % (NY_PHI2 * NZ_PHI2)) % NZ_PHI2;

    {{REAL}} RA01, RB0, RE0, RF0, dEx, dEz;
    {{REAL}} dy = d;
    int ii, jj, kk, materialHx, materialHz;
    int nx = xf - xs;
    int ny = yf - ys;
    int nz = zf - zs;

    if (p1 == 0 && i1 < nx && j1 < ny && k1 < nz) {
        // Subscripts for field arrays
        ii = i1 + xs;
        jj = j1 + ys;
        kk = k1 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,j1)] - 1;
        RB0 = RB[INDEX2D_R(0,j1)];
        RE0 = RE[INDEX2D_R(0,j1)];
        RF0 = RF[INDEX2D_R(0,j1)];

        // Hx
        materialHx = ID[INDEX4D_ID(3,ii,jj,kk)];
        dEz = (Ez[INDEX3D_FIELDS(ii,jj+1,kk)] - Ez[INDEX3D_FIELDS(ii,jj,kk)]) / dy;
        Hx[INDEX3D_FIELDS(ii,jj,kk)] = Hx[INDEX3D_FIELDS(ii,jj,kk)] - updatecoeffsH[INDEX2D_MAT(materialHx,4)] * (RA01 * dEz + RB0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)]);
        PHI1[INDEX4D_PHI1(0,i1,j1,k1)] = RE0 * PHI1[INDEX4D_PHI1(0,i1,j1,k1)] - RF0 * dEz;
    }

    if (p2 == 0 && i2 < nx && j2 < ny && k2 < nz) {
        // Subscripts for field arrays
        ii = i2 + xs;
        jj = j2 + ys;
        kk = k2 + zs;

        // PML coefficients
        RA01 = RA[INDEX2D_R(0,j2)] - 1;
        RB0 = RB[INDEX2D_R(0,j2)];
        RE0 = RE[INDEX2D_R(0,j2)];
        RF0 = RF[INDEX2D_R(0,j2)];

        // Hz
        materialHz = ID[INDEX4D_ID(5,ii,jj,kk)];
        dEx = (Ex[INDEX3D_FIELDS(ii,jj+1,kk)] - Ex[INDEX3D_FIELDS(ii,jj,kk)]) / dy;
        Hz[INDEX3D_FIELDS(ii,jj,kk)] = Hz[INDEX3D_FIELDS(ii,jj,kk)] + updatecoeffsH[INDEX2D_MAT(materialHz,4)] * (RA01 * dEx + RB0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)]);
        PHI2[INDEX4D_PHI2(0,i2,j2,k2)] = RE0 * PHI2[INDEX4D_PHI2(0,i2,j2,k2)] - RF0 * dEx;
    }

}