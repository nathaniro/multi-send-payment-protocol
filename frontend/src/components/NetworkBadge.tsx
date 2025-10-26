function NetworkBadge() {
  const network = import.meta.env.VITE_NETWORK || 'testnet';
  return <span className="text-xs bg-blue-100 px-2 py-1 rounded">{network.toUpperCase()}</span>;
}
export default NetworkBadge;
