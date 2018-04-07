// Generated by using Rcpp::compileAttributes() -> do not edit by hand
// Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#include <RcppArmadillo.h>
#include <RcppEigen.h>
#include <Rcpp.h>

using namespace Rcpp;

// colSumByFac
arma::mat colSumByFac(SEXP sY, SEXP rowSel);
RcppExport SEXP _swne_colSumByFac(SEXP sYSEXP, SEXP rowSelSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type sY(sYSEXP);
    Rcpp::traits::input_parameter< SEXP >::type rowSel(rowSelSEXP);
    rcpp_result_gen = Rcpp::wrap(colSumByFac(sY, rowSel));
    return rcpp_result_gen;
END_RCPP
}
// colMeanVarS
Rcpp::DataFrame colMeanVarS(SEXP sY, SEXP rowSel);
RcppExport SEXP _swne_colMeanVarS(SEXP sYSEXP, SEXP rowSelSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type sY(sYSEXP);
    Rcpp::traits::input_parameter< SEXP >::type rowSel(rowSelSEXP);
    rcpp_result_gen = Rcpp::wrap(colMeanVarS(sY, rowSel));
    return rcpp_result_gen;
END_RCPP
}
// inplaceWinsorizeSparseCols
int inplaceWinsorizeSparseCols(SEXP sY, const int n);
RcppExport SEXP _swne_inplaceWinsorizeSparseCols(SEXP sYSEXP, SEXP nSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< SEXP >::type sY(sYSEXP);
    Rcpp::traits::input_parameter< const int >::type n(nSEXP);
    rcpp_result_gen = Rcpp::wrap(inplaceWinsorizeSparseCols(sY, n));
    return rcpp_result_gen;
END_RCPP
}
// ComputeSNN
Eigen::SparseMatrix<double> ComputeSNN(Eigen::MatrixXd nn_ranked, double prune);
RcppExport SEXP _swne_ComputeSNN(SEXP nn_rankedSEXP, SEXP pruneSEXP) {
BEGIN_RCPP
    Rcpp::RObject rcpp_result_gen;
    Rcpp::RNGScope rcpp_rngScope_gen;
    Rcpp::traits::input_parameter< Eigen::MatrixXd >::type nn_ranked(nn_rankedSEXP);
    Rcpp::traits::input_parameter< double >::type prune(pruneSEXP);
    rcpp_result_gen = Rcpp::wrap(ComputeSNN(nn_ranked, prune));
    return rcpp_result_gen;
END_RCPP
}

static const R_CallMethodDef CallEntries[] = {
    {"_swne_colSumByFac", (DL_FUNC) &_swne_colSumByFac, 2},
    {"_swne_colMeanVarS", (DL_FUNC) &_swne_colMeanVarS, 2},
    {"_swne_inplaceWinsorizeSparseCols", (DL_FUNC) &_swne_inplaceWinsorizeSparseCols, 2},
    {"_swne_ComputeSNN", (DL_FUNC) &_swne_ComputeSNN, 2},
    {NULL, NULL, 0}
};

RcppExport void R_init_swne(DllInfo *dll) {
    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
}
