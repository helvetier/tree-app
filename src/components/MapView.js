import View from 'ol/View';
import { useContext, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';

import { MapContext } from '../spatial/components/Map';
import { setMapView } from '../store/actions';

const getMapViewString = view => {
  const [lon, lat] = view.getCenter();
  const zoom = Math.round(view.getZoom());
  return [zoom, Math.round(lon), Math.round(lat)].join('|');
};
const parseMapViewString = mapViewString => {
  const [zoom, lon, lat] = mapViewString.split('|');
  return { center: [lon, lat], zoom };
};
// Swiss extent in EPSG:3857
const extent = [660000, 5740000, 1180000, 6090000];
const maxZoom = 20;
const minZoom = 2;

function MapView() {
  const map = useContext(MapContext);
  const dispatch = useDispatch();
  const mapViewString = useSelector(state => state.mapView);
  useEffect(() => {
    const { center, zoom } = parseMapViewString(mapViewString);
    const mapView = new View({ center, extent, maxZoom, minZoom, zoom });
    map.on('moveend', () => dispatch(setMapView(getMapViewString(mapView))));
    map.setView(mapView);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);
  return null;
}

export default MapView;