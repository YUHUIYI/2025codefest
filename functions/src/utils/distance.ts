/**
 * 使用 Haversine formula 計算兩點間距離（公里）
 * @param lat1 第一個點的緯度
 * @param lng1 第一個點的經度
 * @param lat2 第二個點的緯度
 * @param lng2 第二個點的經度
 * @returns 兩點間的距離（公里）
 */
export function calculateDistance(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number
): number {
  const R = 6371; // 地球半徑（公里）
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);

  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * 將角度轉換為弧度
 * @param degrees 角度
 * @returns 弧度
 */
function toRad(degrees: number): number {
  return degrees * (Math.PI / 180);
}

