import { transform } from 'ol/proj';
import React, { useContext, useEffect } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { Segment } from 'semantic-ui-react';

import { EPSG2056 } from '../map/projection';
import { MapContext } from '../spatial/components/Map';
import Popup from '../spatial/components/Popup';
import { setMapLocation } from '../store/actions';

import styles from './MapLocationInfo.module.css';

const sourceLayerMapping = {
  altitudinal_zones_1995: 'altitudinalZone',
  altitudinal_zones_2085_less_dry: 'targetAltitudinalZoneModerate',
  altitudinal_zones_2085_dry: 'targetAltitudinalZoneExtreme',
  forest_ecoregions: 'forestEcoregion',
  forest_types: 'forestType',
  silver_fir_areas: 'silverFirArea',
};
const featuresToLocation = (location, feature) => ({
  ...location,
  [sourceLayerMapping[feature.sourceLayer] ||
  feature.sourceLayer]: feature.properties.code.toString(),
});

function MapLocationInfo() {
  const map = useContext(MapContext);
  const dispatch = useDispatch();
  const mapLocation = useSelector(state => state.mapLocation);
  const position =
    mapLocation.coordinate &&
    transform(mapLocation.coordinate, EPSG2056, 'EPSG:3857');
  useEffect(() => {
    map.on('click', event => {
      const coordinate = transform(event.coordinate, 'EPSG:3857', EPSG2056);
      const features = map.getFeaturesAtPixel(event.pixel) || [];
      const location = features
        .filter(feature => feature.properties.code)
        .reduce(featuresToLocation, {});
      dispatch(setMapLocation({ ...location, coordinate }));
    });
  }, [map, dispatch]);
  return (
    <Popup position={position}>
      <Segment compact inverted className={styles.popup}>
        <pre>{JSON.stringify(mapLocation, null, 2)}</pre>
      </Segment>
    </Popup>
  );
}

export default MapLocationInfo;