import React, { useState, useEffect } from 'react';
import {
  Container,
  Grid,
  Paper,
  Typography,
  Button,
  Card,
  CardContent,
  Box,
  Chip,
  LinearProgress,
  Alert
} from '@mui/material';
import {
  Agriculture as FarmIcon,
  AttachMoney as MoneyIcon,
  Timeline as ChartIcon,
  Add as AddIcon,
  Refresh as RefreshIcon,
  Security as TokenIcon
} from '@mui/icons-material';

interface YieldAsset {
  assetId: string;
  tokenId: string;
  farmerId: string;
  cropType: string;
  season: number;
  predictedYield: number;
  confidence: number;
  tokenAmount: number;
  currentValue: number;
  status: string;
}

const Dashboard: React.FC = () => {
  const [assets, setAssets] = useState<YieldAsset[]>([]);
  const [loading, setLoading] = useState(false);

  const loadData = async () => {
    setLoading(true);
    try {
      // Placeholder for API call
      const mockAssets: YieldAsset[] = [
        {
          assetId: "ASSET_2024_WHEAT_001",
          tokenId: "AYW-2024-WHEAT-001",
          farmerId: "FARMER_001",
          cropType: "Wheat",
          season: 2024,
          predictedYield: 5000,
          confidence: 0.85,
          tokenAmount: 5000,
          currentValue: 25000,
          status: "PREDICTED"
        }
      ];
      setAssets(mockAssets);
    } catch (error) {
      console.error('Failed to load data:', error);
    }
    setLoading(false);
  };

  useEffect(() => {
    loadData();
  }, []);

  const totalTokens = assets.reduce((sum, asset) => sum + asset.tokenAmount, 0);
  const totalValue = assets.reduce((sum, asset) => sum + asset.currentValue, 0);

  return (
    <Container maxWidth="xl" sx={{ mt: 4, mb: 4 }}>
      {/* Header */}
      <Grid container spacing={3} alignItems="center" sx={{ mb: 4 }}>
        <Grid item xs={12} md={8}>
          <Typography variant="h4" gutterBottom>
            🌾 AgriYield Farmer Portal
          </Typography>
          <Typography variant="subtitle1" color="textSecondary">
            Tokenize, trade, and secure loans with your yield predictions
          </Typography>
        </Grid>
        <Grid item xs={12} md={4} sx={{ textAlign: 'right' }}>
          <Button
            variant="contained"
            color="primary"
            startIcon={<AddIcon />}
            sx={{ mr: 2 }}
          >
            Tokenize Yield
          </Button>
          <Button
            variant="outlined"
            startIcon={<RefreshIcon />}
            onClick={loadData}
          >
            Refresh
          </Button>
        </Grid>
      </Grid>

      {/* Stats Cards */}
      <Grid container spacing={3} sx={{ mb: 4 }}>
        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <TokenIcon sx={{ mr: 1, color: 'primary.main' }} />
                <Typography variant="h6">Total Tokens</Typography>
              </Box>
              <Typography variant="h4">{totalTokens.toLocaleString()}</Typography>
              <Typography variant="body2" color="textSecondary">
                Yield tokens owned
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <MoneyIcon sx={{ mr: 1, color: 'success.main' }} />
                <Typography variant="h6">Portfolio Value</Typography>
              </Box>
              <Typography variant="h4">${totalValue.toLocaleString()}</Typography>
              <Typography variant="body2" color="textSecondary">
                Current market value
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <FarmIcon sx={{ mr: 1, color: 'warning.main' }} />
                <Typography variant="h6">Active Farms</Typography>
              </Box>
              <Typography variant="h4">{assets.length}</Typography>
              <Typography variant="body2" color="textSecondary">
                Farms with tokens
              </Typography>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} sm={6} md={3}>
          <Card>
            <CardContent>
              <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
                <ChartIcon sx={{ mr: 1, color: 'info.main' }} />
                <Typography variant="h6">Avg Confidence</Typography>
              </Box>
              <Typography variant="h4">85%</Typography>
              <Typography variant="body2" color="textSecondary">
                ML prediction accuracy
              </Typography>
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      {/* Yield Assets */}
      <Paper sx={{ p: 3 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 3 }}>
          <Typography variant="h6">Your Yield Assets</Typography>
          <Chip 
            label={`${assets.length} assets`} 
            color="primary" 
            size="small"
          />
        </Box>

        {loading && <LinearProgress />}

        <Grid container spacing={2}>
          {assets.map((asset) => (
            <Grid item xs={12} sm={6} md={4} key={asset.assetId}>
              <Card>
                <CardContent>
                  <Typography variant="h6" gutterBottom>
                    {asset.cropType} {asset.season}
                  </Typography>
                  <Typography color="textSecondary" gutterBottom>
                    {asset.assetId}
                  </Typography>
                  <Box sx={{ my: 2 }}>
                    <Typography variant="body2">
                      <strong>Predicted Yield:</strong> {asset.predictedYield.toLocaleString()} kg
                    </Typography>
                    <Typography variant="body2">
                      <strong>Tokens:</strong> {asset.tokenAmount.toLocaleString()}
                    </Typography>
                    <Typography variant="body2">
                      <strong>Value:</strong> ${asset.currentValue.toLocaleString()}
                    </Typography>
                    <Typography variant="body2">
                      <strong>Confidence:</strong> {(asset.confidence * 100).toFixed(0)}%
                    </Typography>
                  </Box>
                  <Chip 
                    label={asset.status} 
                    size="small" 
                    color={asset.status === 'PREDICTED' ? 'primary' : 'success'}
                  />
                </CardContent>
              </Card>
            </Grid>
          ))}

          {assets.length === 0 && (
            <Grid item xs={12}>
              <Alert severity="info" sx={{ textAlign: 'center', py: 4 }}>
                <Typography variant="h6" gutterBottom>
                  No yield assets yet
                </Typography>
                <Typography variant="body2" gutterBottom>
                  Tokenize your yield predictions to create digital assets
                </Typography>
                <Button
                  variant="contained"
                  startIcon={<AddIcon />}
                  sx={{ mt: 2 }}
                >
                  Tokenize First Yield
                </Button>
              </Alert>
            </Grid>
          )}
        </Grid>
      </Paper>
    </Container>
  );
};

export default Dashboard;
